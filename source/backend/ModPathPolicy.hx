package backend;

using StringTools;

/**
 * Dependency-free path rules shared by the mod loader and the `.zip` mod
 * importer (`mobile.files.ModZipInstaller`).
 *
 * Everything that comes from user content - a zip entry name, a mod folder
 * name, a file referenced by a `pack.json` - is funnelled through these
 * helpers so the exact same rules apply everywhere:
 *
 * - no absolute paths (POSIX `/...`, Windows `C:...` or UNC `//server`);
 * - no `..` segments, so nothing can escape `mods/`;
 * - no NUL/control characters and no Windows-illegal characters;
 * - no Windows device names (`con`, `nul`, `com1`, ...);
 * - bounded length and depth, so pathological archives cannot create absurd
 *   trees.
 *
 * The helpers never touch the filesystem, which keeps them safe to run before
 * sanitizing a single byte and lets `tests/haxe/ModZipImportSpec.hx` exercise
 * them with `haxe --interp` (no Flixel/haxelib dependencies).
 */
@:unreflective
class ModPathPolicy
{
	/** Longest relative path accepted, in characters. */
	public static inline final MAX_PATH_LENGTH:Int = 180;

	/** Deepest relative path accepted (`a/b/c` is depth 3). */
	public static inline final MAX_PATH_DEPTH:Int = 16;

	/** Longest mod folder name accepted under `mods/`. */
	public static inline final MAX_FOLDER_NAME_LENGTH:Int = 64;

	/**
	 * Folders directly under `mods/` that hold loose assets shared by every mod
	 * instead of a single installable mod. `Mods.ignoreModFolders` mirrors this
	 * list, and a mod folder may never reuse one of these names.
	 */
	public static final RESERVED_MOD_FOLDERS:Array<String> = [
		'characters', 'custom_events', 'custom_notetypes', 'data', 'songs', 'music', 'sounds',
		'shaders', 'videos', 'images', 'stages', 'weeks', 'fonts', 'scripts', 'achievements'
	];

	static final ILLEGAL_CHARACTERS:String = '<>:"|?*';

	static final WINDOWS_DEVICE_NAMES:Array<String> = [
		'con', 'prn', 'aux', 'nul',
		'com1', 'com2', 'com3', 'com4', 'com5', 'com6', 'com7', 'com8', 'com9',
		'lpt1', 'lpt2', 'lpt3', 'lpt4', 'lpt5', 'lpt6', 'lpt7', 'lpt8', 'lpt9'
	];

	/**
	 * Normalizes a relative path (zip entry, asset reference) into a portable
	 * `a/b/c` form.
	 *
	 * Backslashes are treated as separators so a Windows-made archive cannot
	 * smuggle `..\\..\\evil` past the check, empty and `.` segments are dropped,
	 * and everything that could escape the destination is rejected instead of
	 * being silently rewritten.
	 *
	 * @return the normalized path, or `null` when the input is unsafe
	 */
	public static function normalizeRelative(raw:String):Null<String>
	{
		if(raw == null) return null;

		var value:String = raw.replace('\\', '/');
		if(value.length == 0) return null;
		if(value.startsWith('/')) return null; // absolute POSIX path or UNC share
		if(value.length > 1 && value.charAt(1) == ':' && isAsciiLetter(value.charAt(0))) return null; // C:\ or C:/

		var parts:Array<String> = value.split('/');
		var safe:Array<String> = [];
		for(part in parts)
		{
			if(part.length == 0 || part == '.') continue;
			if(part == '..') return null;
			if(!isSafeSegment(part)) return null;
			safe.push(part);
		}

		if(safe.length == 0 || safe.length > MAX_PATH_DEPTH) return null;

		var joined:String = safe.join('/');
		if(joined.length > MAX_PATH_LENGTH) return null;
		return joined;
	}

	/** `true` when {@link normalizeRelative} accepts `raw`. */
	public static function isSafeRelative(raw:String):Bool
		return normalizeRelative(raw) != null;

	/**
	 * Turns arbitrary text (a zip name, a `pack.json` name, a folder picked by
	 * the user) into a folder name that is safe to create under `mods/`.
	 *
	 * Unsafe characters become `_`, path separators and a trailing `.zip` are
	 * dropped, reserved asset folders get a `_mod` suffix and Windows device
	 * names get a leading underscore. The result is never empty.
	 *
	 * @param fallback name used when nothing usable is left (defaults to `imported_mod`)
	 */
	public static function sanitizeFolderName(raw:String, fallback:String = 'imported_mod'):String
	{
		var name:String = raw == null ? '' : raw.replace('\\', '/');
		var slash:Int = name.lastIndexOf('/');
		if(slash >= 0) name = name.substr(slash + 1);
		if(name.toLowerCase().endsWith('.zip')) name = name.substr(0, name.length - 4);

		var buffer:StringBuf = new StringBuf();
		for(i in 0...name.length)
		{
			var character:String = name.charAt(i);
			var code:Int = name.charCodeAt(i);
			if(code < 0x20 || code == 0x7F || ILLEGAL_CHARACTERS.indexOf(character) >= 0) buffer.add('_');
			else buffer.add(character);
		}

		var cleaned:String = buffer.toString();
		while(cleaned.indexOf('__') >= 0) cleaned = cleaned.split('__').join('_');
		cleaned = cleaned.trim();
		// A leading dot would hide the folder from the mods list, and the engine
		// uses dot-folders for its own staging work.
		while(cleaned.startsWith('.') || cleaned.startsWith('_')) cleaned = cleaned.substr(1);
		while(cleaned.endsWith('.') || cleaned.endsWith('_')) cleaned = cleaned.substr(0, cleaned.length - 1);
		cleaned = cleaned.trim();

		if(cleaned.length > MAX_FOLDER_NAME_LENGTH) cleaned = cleaned.substr(0, MAX_FOLDER_NAME_LENGTH).trim();
		if(cleaned.length == 0) return fallback;
		if(RESERVED_MOD_FOLDERS.contains(cleaned.toLowerCase())) cleaned += '_mod';
		if(WINDOWS_DEVICE_NAMES.contains(baseName(cleaned))) cleaned = '_' + cleaned;
		return cleaned;
	}

	/**
	 * `true` when `name` can be used verbatim as a folder name under `mods/`
	 * (no separators, no traversal, not a reserved asset folder).
	 */
	public static function isSafeFolderName(name:String):Bool
	{
		if(name == null || name.length == 0 || name.length > MAX_FOLDER_NAME_LENGTH) return false;
		if(name.startsWith('.')) return false; // staging/leftover folders are never mods
		if(RESERVED_MOD_FOLDERS.contains(name.toLowerCase())) return false;
		if(WINDOWS_DEVICE_NAMES.contains(baseName(name))) return false;

		var normalized:Null<String> = normalizeRelative(name);
		return normalized != null && normalized == name;
	}

	/**
	 * Joins `relative` under `base` after validating both, so the result is
	 * guaranteed to stay inside `base`.
	 *
	 * @return the joined path, or `null` when `relative` or `base` is unsafe
	 */
	public static function resolveInside(base:String, relative:String):Null<String>
	{
		var normalized:Null<String> = normalizeRelative(relative);
		if(normalized == null) return null;

		var basePath:String = base == null ? '' : base.replace('\\', '/');
		for(part in basePath.split('/'))
			if(part == '..') return null;

		while(basePath.endsWith('/')) basePath = basePath.substr(0, basePath.length - 1);
		return basePath.length == 0 ? normalized : basePath + '/' + normalized;
	}

	static function isSafeSegment(segment:String):Bool
	{
		if(segment.length == 0 || segment.length > 255) return false;
		if(segment.endsWith(' ') || segment.endsWith('.')) return false; // Windows silently trims these

		for(i in 0...segment.length)
		{
			var character:String = segment.charAt(i);
			var code:Int = segment.charCodeAt(i);
			if(code < 0x20 || code == 0x7F) return false;
			if(ILLEGAL_CHARACTERS.indexOf(character) >= 0) return false;
		}

		return !WINDOWS_DEVICE_NAMES.contains(baseName(segment));
	}

	/** Lowercased part before the first dot, used for Windows device-name checks. */
	static function baseName(segment:String):String
	{
		var dot:Int = segment.indexOf('.');
		var name:String = dot < 0 ? segment : segment.substr(0, dot);
		return name.trim().toLowerCase();
	}

	static inline function isAsciiLetter(character:String):Bool
	{
		if(character == null || character.length == 0) return false;
		var code:Int = character.charCodeAt(0);
		return (code >= 65 && code <= 90) || (code >= 97 && code <= 122);
	}
}
