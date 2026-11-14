package backend;

import backend.ScriptSecurityScanner.ScriptSecurityFinding;

using StringTools;

private typedef ModSandboxConfig =
{
	var enabled:Bool;
	var packEnabled:Bool;
	var playerOverride:Null<Bool>;
	var allowlist:Array<String>;
}

/** Security decision made before a Lua/Python/HScript softmod script is started. */
typedef ModSecurityCheck =
{
	var scriptName:String;
	var displayPath:String;
	var language:String;
	var softmod:Bool;
	var sandboxed:Bool;
	var optedOut:Bool;
	var modFolder:Null<String>;
	var modName:String;
	var allowlist:Array<String>;
	var findings:Array<ScriptSecurityFinding>;

	/** The player's Mods menu choice for the owning mod; `null` while its `pack.json` decides. */
	var playerOverride:Null<Bool>;
}

/** Sandbox state of one mod folder, as shown by Mod Info in the Mods menu. */
typedef ModSecurityStatus =
{
	/** Mod folder under `mods/` (empty for loose scripts, which always stay sandboxed). */
	var folder:String;

	/** Whether scripts from this mod are scanned and sandboxed right now. */
	var enabled:Bool;

	/** What the mod's own `pack.json` asks for, before the player's choice. */
	var packEnabled:Bool;

	/** The player's choice: `true` forces the sandbox on, `false` turns it off, `null` follows `pack.json`. */
	var playerOverride:Null<Bool>;

	/** Rule IDs the mod's `pack.json` exempts while the sandbox is on. */
	var allowlist:Array<String>;
}

/**
 * Basic defence-in-depth for untrusted Lua, Python and HScript softmod scripts.
 *
 * A source denylist stops suspicious scripts before any top-level code runs.
 * The script runtimes then apply a second layer: dangerous Lua libraries are
 * replaced, Python cannot resolve host classes, standalone HScript cannot
 * import host classes, privileged engine callbacks are guarded, and embedded
 * HScript is scanned separately.
 *
 * This is intentionally described as a basic sandbox. It reduces the attack
 * surface of accidental or straightforward malicious scripts; it is not an
 * OS/process isolation boundary.
 *
 * The sandbox is on for every mod by default. A mod's `pack.json` can opt out,
 * and the player has the last word per mod: Mod Info in the Mods menu turns it
 * off (or forces it back on) through `setEnabled()`, and that choice is kept
 * in `modSecurity.txt` next to `modsList.txt`.
 *
 * Pattern-based policy inspired by Psych Plus's ModSecurity design:
 * https://github.com/Psych-Plus-Team/FNF-PlusEngine
 */
@:unreflective
class ModSecurity
{
	public static inline final LOOSE_MOD_NAME:String = '<loose mods>';

	/**
	 * Per-mod choices made in the Mods menu, stored next to `modsList.txt`:
	 * one `<mod folder>|0` (ModSecurity off) or `<mod folder>|1` (forced on)
	 * per line. A mod without a line follows its `pack.json`.
	 */
	public static inline final PLAYER_OVERRIDES_FILE:String = 'modSecurity.txt';

	static final BLOCKED_CALLBACK_RULES:Map<String, String> = [
		'saveFile' => 'engine.file-write',
		'deleteFile' => 'engine.file-write',
		'getTextFromFile' => 'engine.file-read',
		'checkFileExists' => 'engine.file-read',
		'directoryFileList' => 'engine.file-read',
		'addLuaScript' => 'engine.script-loader',
		'addPythonScript' => 'engine.script-loader',
		'addHScript' => 'engine.script-loader',
		'addScript' => 'engine.script-loader',
		// #94 follow-up: the 4th-wall API can inspect the player's desktop.
		// Reading/replacing the OS clipboard and screenshotting every monitor
		// are exactly the exfiltration paths a sandbox exists to block, so
		// they need an explicit allowlist entry like file access does.
		'getClipboardText' => 'engine.clipboard',
		'setClipboardText' => 'engine.clipboard',
		'getOpenWindowTitles' => 'engine.window-list',
		'captureDesktop' => 'engine.screen-capture'
	];

	static var configCache:Map<String, ModSandboxConfig> = [];
	static var warnedOptOutMods:Map<String, Bool> = [];
	static var hintedBlockedMods:Map<String, Bool> = [];

	// Mods menu choices, keyed by mod folder (true = forced on, false = off).
	// Private state of an @:unreflective class: scripts cannot reach it.
	static var playerOverrides:Map<String, Bool> = [];
	static var playerOverridesLoaded:Bool = false;

	/** Inspect one script. Findings mean the caller must not create/execute it. */
	public static function checkScript(scriptName:String, source:String, language:String):ModSecurityCheck
	{
		var normalizedPath:String = normalizePath(scriptName);
		var owner = findModOwner(normalizedPath);
		var config:ModSandboxConfig = owner.softmod ? getConfig(owner.folder)
			: {enabled: false, packEnabled: false, playerOverride: null, allowlist: []};
		var sandboxed:Bool = owner.softmod && config.enabled;
		var findings:Array<ScriptSecurityFinding> = [];

		if(sandboxed)
		{
			if(source == null)
			{
				findings.push({
					line: 1,
					rule: 'security.unreadable',
					description: 'script source could not be read for security scanning',
					snippet: ''
				});
			}
			else
			{
				findings = ScriptSecurityScanner.scan(source, language, config.allowlist);

				// Lua can bridge to HScript. Scan the same physical source for the
				// concrete Haxe operation when a bridge is present, while allowing
				// ordinary runHaxeCode usage that only manipulates game objects.
				if(language != null && language.toLowerCase() == 'lua'
					&& ~/\b(?:runHaxeCode|runHaxeFunction|addHaxeLibrary)\b/.match(source))
				{
					mergeFindings(findings, ScriptSecurityScanner.scan(source, 'haxe', config.allowlist));
				}

				if(source.indexOf(String.fromCharCode(0)) != -1
					&& !ScriptSecurityScanner.isAllowed('security.binary-source', config.allowlist))
				{
					findings.push({
						line: 1,
						rule: 'security.binary-source',
						description: 'NUL byte in script source',
						snippet: ''
					});
				}
			}
		}

		return {
			scriptName: scriptName == null ? '' : scriptName,
			displayPath: displayPath(normalizedPath, owner.folder),
			language: language == null ? '' : language,
			softmod: owner.softmod,
			sandboxed: sandboxed,
			optedOut: owner.softmod && !config.enabled,
			modFolder: owner.folder,
			modName: owner.folder == null ? (owner.softmod ? LOOSE_MOD_NAME : '<engine>') : owner.folder,
			allowlist: config.allowlist.copy(),
			findings: findings,
			playerOverride: config.playerOverride
		};
	}

	/**
	 * Emit the user-facing warning/block report. `sink` is normally the
	 * PlayState debug console; trace output is always produced as a durable log.
	 */
	public static function report(check:ModSecurityCheck, ?sink:String->Void):Void
	{
		if(check == null) return;

		if(check.optedOut && !warnedOptOutMods.exists(check.modName))
		{
			warnedOptOutMods.set(check.modName, true);
			// A null override means the mod's pack.json made this decision.
			var reason:String = check.playerOverride == false
				? 'ModSecurity is turned off for mod "${check.modName}" in the Mods menu (Mod Info).'
				: 'mod "${check.modName}" opted out of script sandboxing in pack.json.';
			emit('[ModSecurity] WARNING: $reason Its Lua/Python/HScript scripts run with full engine privileges.', sink);
		}

		if(check.findings.length == 0) return;
		var findingSuffix:String = check.findings.length == 1 ? '' : 's';
		emit('[ModSecurity] BLOCKED ${check.language} script "${check.displayPath}" from mod "${check.modName}" '
			+ 'before execution (${check.findings.length} security finding$findingSuffix).', sink);
		for(finding in check.findings)
		{
			var snippet:String = finding.snippet.length > 0 ? ' | ${finding.snippet}' : '';
			emit('[ModSecurity] mod="${check.modName}" script="${check.displayPath}" line=${finding.line} '
				+ 'rule=${finding.rule}: ${finding.description}$snippet', sink);
		}

		#if MODS_ALLOWED
		// Say once per mod where the player can make the call. Loose scripts have
		// no entry in the Mods menu and always stay sandboxed, and a file that is
		// not readable text would not run without the sandbox either.
		if(check.modFolder != null && !hintedBlockedMods.exists(check.modFolder) && hasPolicyFinding(check.findings))
		{
			hintedBlockedMods.set(check.modFolder, true);
			emit('[ModSecurity] Only if you trust mod "${check.modName}": Mod Info in the Mods menu can turn ModSecurity off '
				+ 'for it, which lets its blocked scripts run.', sink);
		}
		#end
	}

	/** Whether a finding is about what the script does, not about a file that cannot be read as text. */
	static function hasPolicyFinding(findings:Array<ScriptSecurityFinding>):Bool
	{
		for(finding in findings)
			if(finding.rule != 'security.unreadable' && finding.rule != 'security.binary-source') return true;
		return false;
	}

	public static function formatRuntimeBlock(modName:String, scriptName:String, capability:String, ?line:Int = 0):String
	{
		var owner:String = modName == null || modName.length == 0 ? LOOSE_MOD_NAME : modName;
		var where:String = line > 0 ? ' line=$line' : '';
		return '[ModSecurity] BLOCKED runtime call in mod="$owner" script="${displayPath(normalizePath(scriptName), modName)}"$where: $capability';
	}

	public static function runtimeRuleForCallback(callbackName:String):Null<String>
		return BLOCKED_CALLBACK_RULES.get(callbackName);

	public static inline function isRuleAllowed(rule:String, allowlist:Array<String>):Bool
		return ScriptSecurityScanner.isAllowed(rule, allowlist);

	public static function isRuntimeCallbackBlocked(callbackName:String, sandboxed:Bool, allowlist:Array<String>):Bool
	{
		if(!sandboxed) return false;
		var rule:String = BLOCKED_CALLBACK_RULES.get(callbackName);
		return rule != null && !isRuleAllowed(rule, allowlist);
	}

	/** Classes that reflection callbacks must never expose to sandboxed mods. */
	public static function isPrivilegedClass(className:String):Bool
	{
		if(className == null) return false;
		var value:String = className.trim().toLowerCase();
		if(value.length == 0) return false;

		for(prefix in [
			'sys.', 'cpp.', 'neko.', 'hl.', 'java.', 'objc.', 'backend.modsecurity', 'backend.mods',
			'psychlua.', 'haxe.http', 'openfl.lib', 'openfl.net', 'openfl.filesystem', 'lime.system',
			'lime.app', 'lime.net', 'utils.platformutil', 'system.', 'slushithings.', 'android.', 'ios.', 'mac.'
		])
		{
			if(value == prefix || value.startsWith(prefix)) return true;
		}
		return value == 'sys' || value == 'type' || value == 'reflect' || value == 'main'
			|| value == 'modsecurity' || value == 'mods';
	}

	/**
	 * Lua code installed immediately after openlibs(). Each non-allowlisted
	 * standard-library category becomes a sealed proxy whose calls fail before
	 * reaching LuaJIT/FFI/OS code. package.loaded is replaced too so require()
	 * cannot recover a reference after only one category was allowlisted.
	 */
	public static function luaBootstrap(allowlist:Array<String>):String
	{
		var out:StringBuf = new StringBuf();
		out.add("local function __phoenix_block(name)\n");
		out.add("  return function(...) error('[ModSecurity] blocked Lua call: ' .. name, 2) end\n");
		out.add("end\n");
		out.add("local function __phoenix_proxy(name)\n");
		out.add("  return setmetatable({}, {\n");
		out.add("    __index = function(_, key) return __phoenix_block(name .. '.' .. tostring(key)) end,\n");
		out.add("    __newindex = function() error('[ModSecurity] blocked Lua library mutation: ' .. name, 2) end,\n");
		out.add("    __metatable = false\n");
		out.add("  })\n");
		out.add("end\n");

		if(!isRuleAllowed('lua.os', allowlist))
		{
			out.add("os = __phoenix_proxy('os')\n");
			out.add("if package and package.loaded then package.loaded.os = os end\n");
		}
		if(!isRuleAllowed('lua.io', allowlist))
		{
			out.add("io = __phoenix_proxy('io')\n");
			out.add("if package and package.loaded then package.loaded.io = io end\n");
		}
		if(!isRuleAllowed('lua.native', allowlist))
		{
			out.add("debug = __phoenix_proxy('debug')\n");
			out.add("ffi = __phoenix_proxy('ffi')\n");
			out.add("jit = __phoenix_proxy('jit')\n");
			out.add("if package and package.loaded then package.loaded.debug = debug; package.loaded.ffi = ffi; package.loaded.jit = jit end\n");
			out.add("if package then package.loadlib = __phoenix_block('package.loadlib'); package.cpath = '' end\n");
			out.add("if package and package.loaders then package.loaders[3] = __phoenix_block('package C loader'); package.loaders[4] = __phoenix_block('package C root loader') end\n");
		}
		if(!isRuleAllowed('lua.dynamic-code', allowlist))
		{
			for(name in ['dofile', 'loadfile', 'loadstring', 'load'])
				out.add('$name = __phoenix_block("$name")\n');
		}
		if(!isRuleAllowed('lua.package', allowlist))
		{
			out.add("require = __phoenix_block('require')\n");
			out.add("module = __phoenix_block('module')\n");
			out.add("package = __phoenix_proxy('package')\n");
		}
		return out.toString();
	}

	/** Drop cached pack.json decisions (mainly useful after an in-process reload). */
	public static function clearCache():Void
	{
		configCache.clear();
		warnedOptOutMods.clear();
		hintedBlockedMods.clear();
	}

	/**
	 * Sandbox state of one mod folder: what its `pack.json` asks for, what the
	 * player chose in the Mods menu, and the result that script loading uses.
	 */
	public static function getStatus(folder:String):ModSecurityStatus
	{
		var named:Bool = isNamedModFolder(folder);
		var config:ModSandboxConfig = getConfig(named ? folder : null);
		return {
			folder: named ? folder : '',
			enabled: config.enabled,
			packEnabled: config.packEnabled,
			playerOverride: config.playerOverride,
			allowlist: config.allowlist
		};
	}

	/**
	 * Turn the sandbox on or off for one mod, as the player asked in the Mods
	 * menu. The player always wins over the mod's `pack.json`; only a choice
	 * that differs from it is stored, so going back to the mod's own default
	 * drops the entry again. Scripts loaded from now on use the new state.
	 *
	 * @return `false` when `folder` is not a mod folder, or when the choice
	 *         could not be written to `modSecurity.txt` (it then only lasts
	 *         until the choices are read again)
	 */
	public static function setEnabled(folder:String, enabled:Bool):Bool
	{
		if(!isNamedModFolder(folder)) return false;
		return setPlayerOverride(folder, enabled == getConfig(folder).packEnabled ? null : enabled);
	}

	/** The player's stored choice for a mod folder; `null` while its `pack.json` decides. */
	public static function getPlayerOverride(folder:String):Null<Bool>
	{
		if(!isNamedModFolder(folder)) return null;
		ensurePlayerOverridesLoaded();
		return playerOverrides.exists(folder) ? playerOverrides.get(folder) : null;
	}

	/**
	 * Store the player's choice for a mod folder and save `modSecurity.txt`:
	 * `true` forces the sandbox on, `false` turns it off and `null` forgets
	 * the choice. Loose scripts have no folder and cannot be given one.
	 *
	 * @return `false` when `folder` is not a mod folder or the file could not be written
	 */
	public static function setPlayerOverride(folder:String, enabled:Null<Bool>):Bool
	{
		if(!isNamedModFolder(folder)) return false;
		ensurePlayerOverridesLoaded();
		if(enabled == null) playerOverrides.remove(folder);
		else playerOverrides.set(folder, enabled);

		// Re-read the policy for this mod and let its warning/hint fire again.
		configCache.remove(folder);
		warnedOptOutMods.remove(folder);
		hintedBlockedMods.remove(folder);
		return savePlayerOverrides();
	}

	/**
	 * Call after new files were installed into a mod folder (a `.zip` import,
	 * also one that replaces an existing mod). "Off" was the player's decision
	 * about the mod that used to be there, so that choice is dropped and the
	 * new files start under their own `pack.json`, sandboxed by default. A
	 * forced "on" stays.
	 *
	 * @return `true` when an "off" choice was dropped
	 */
	public static function revokePlayerOptOut(folder:String):Bool
	{
		if(getPlayerOverride(folder) != false) return false;
		setPlayerOverride(folder, null);
		return true;
	}

	/**
	 * Forget the choices held in memory so the next lookup reads
	 * `modSecurity.txt` again, and drop the cached `pack.json` decisions with
	 * them. The Mods menu calls this whenever it is (re)built.
	 */
	public static function reloadPlayerOverrides():Void
	{
		playerOverrides = [];
		playerOverridesLoaded = false;
		clearCache();
	}

	/**
	 * Parse the text of `modSecurity.txt`. Anything that is not
	 * `<mod folder>|0` or `<mod folder>|1` is skipped, so a damaged file can
	 * only fall back to the default policy. The folder part is taken as it is
	 * written, padding included: a line never ends up naming another folder
	 * than the one it was saved for.
	 */
	public static function parsePlayerOverrides(text:String):Map<String, Bool>
	{
		var result:Map<String, Bool> = [];
		if(text == null) return result;
		if(text.charCodeAt(0) == 0xFEFF) text = text.substr(1); // UTF-8 BOM from some editors

		for(rawLine in text.split('\n'))
		{
			var line:String = rawLine.endsWith('\r') ? rawLine.substr(0, rawLine.length - 1) : rawLine; // CRLF
			var separator:Int = line.lastIndexOf('|');
			if(separator < 1) continue;

			var folder:String = line.substr(0, separator);
			if(!isNamedModFolder(folder)) continue;
			switch(line.substr(separator + 1).trim())
			{
				case '0': result.set(folder, false);
				case '1': result.set(folder, true);
				default:
			}
		}
		return result;
	}

	/** Text of `modSecurity.txt` for a set of choices, one sorted `<mod folder>|<0 or 1>` per line. */
	public static function serializePlayerOverrides(overrides:Map<String, Bool>):String
	{
		var folders:Array<String> = [for(folder in overrides.keys()) folder];
		folders.sort(function(a:String, b:String):Int return a < b ? -1 : (a > b ? 1 : 0));
		return [for(folder in folders) folder + '|' + (overrides.get(folder) ? '1' : '0')].join('\n');
	}

	/** Loose content directly under `mods/` has no folder, so it can never be given a choice. */
	static function isNamedModFolder(folder:Null<String>):Bool
	{
		return folder != null && folder.trim().length > 0 && folder.indexOf('\n') < 0 && folder.indexOf('\r') < 0;
	}

	static function ensurePlayerOverridesLoaded():Void
	{
		if(playerOverridesLoaded) return;
		playerOverridesLoaded = true;
		#if (MODS_ALLOWED && sys)
		try
		{
			if(sys.FileSystem.exists(PLAYER_OVERRIDES_FILE) && !sys.FileSystem.isDirectory(PLAYER_OVERRIDES_FILE))
				playerOverrides = parsePlayerOverrides(sys.io.File.getContent(PLAYER_OVERRIDES_FILE));
		}
		catch(e:Dynamic)
		{
			// Unreadable choices fall back to the default: every mod keeps its own policy.
			playerOverrides = [];
			emit('[ModSecurity] Could not read $PLAYER_OVERRIDES_FILE ($e). Every mod uses its default policy.', null);
		}
		#end
	}

	static function savePlayerOverrides():Bool
	{
		#if (MODS_ALLOWED && sys)
		try
		{
			var text:String = serializePlayerOverrides(playerOverrides);
			if(text.length > 0) sys.io.File.saveContent(PLAYER_OVERRIDES_FILE, text);
			else if(sys.FileSystem.exists(PLAYER_OVERRIDES_FILE)) sys.FileSystem.deleteFile(PLAYER_OVERRIDES_FILE);
			return true;
		}
		catch(e:Dynamic)
		{
			emit('[ModSecurity] Could not save $PLAYER_OVERRIDES_FILE ($e). The choice is not remembered.', null);
			return false;
		}
		#else
		return true;
		#end
	}

	static function getConfig(folder:Null<String>):ModSandboxConfig
	{
		// Loose files in mods/ are always sandboxed and cannot opt out.
		if(folder == null) return {enabled: true, packEnabled: true, playerOverride: null, allowlist: []};
		if(configCache.exists(folder))
		{
			var cached:ModSandboxConfig = configCache.get(folder);
			return {
				enabled: cached.enabled,
				packEnabled: cached.packEnabled,
				playerOverride: cached.playerOverride,
				allowlist: cached.allowlist.copy()
			};
		}

		var packEnabled:Bool = true;
		var allowlist:Array<String> = [];
		#if MODS_ALLOWED
		var pack:Dynamic = Mods.getPack(folder);
		if(pack != null)
		{
			if(Reflect.field(pack, 'scriptSandbox') == false || Reflect.field(pack, 'allowUnsafeScripts') == true)
				packEnabled = false;
			appendAllowlist(allowlist, Reflect.field(pack, 'scriptSandboxAllowlist'));

			// Also accept a grouped form for pack authors that keep metadata tidy:
			// "scriptSecurity": {"enabled": true, "allowlist": [...]}
			var grouped:Dynamic = Reflect.field(pack, 'scriptSecurity');
			if(grouped != null)
			{
				if(Reflect.field(grouped, 'enabled') == false) packEnabled = false;
				appendAllowlist(allowlist, Reflect.field(grouped, 'allowlist'));
			}
		}
		#end

		// The player's choice in the Mods menu wins over the mod's pack.json.
		var playerOverride:Null<Bool> = getPlayerOverride(folder);
		var enabled:Bool = playerOverride != null ? playerOverride : packEnabled;

		var config:ModSandboxConfig = {enabled: enabled, packEnabled: packEnabled, playerOverride: playerOverride, allowlist: allowlist};
		configCache.set(folder, config);
		return {enabled: enabled, packEnabled: packEnabled, playerOverride: playerOverride, allowlist: allowlist.copy()};
	}

	static function appendAllowlist(output:Array<String>, raw:Dynamic):Void
	{
		if(raw == null || !Std.isOfType(raw, Array)) return;
		for(value in (cast raw:Array<Dynamic>))
		{
			if(!Std.isOfType(value, String)) continue;
			var rule:String = (cast value:String).trim();
			if(rule.length > 0 && !output.contains(rule)) output.push(rule);
		}
	}

	static function mergeFindings(output:Array<ScriptSecurityFinding>, extra:Array<ScriptSecurityFinding>):Void
	{
		for(candidate in extra)
		{
			var duplicate:Bool = false;
			for(existing in output)
			{
				if(existing.line == candidate.line && existing.rule == candidate.rule)
				{
					duplicate = true;
					break;
				}
			}
			if(!duplicate) output.push(candidate);
		}
	}

	static function findModOwner(path:String):{softmod:Bool, folder:Null<String>}
	{
		var lower:String = path.toLowerCase();
		var start:Int = -1;
		if(lower.startsWith('mods/')) start = 5;
		else
		{
			var marker:Int = lower.lastIndexOf('/mods/');
			if(marker >= 0) start = marker + 6;
		}
		if(start < 0 || start > path.length) return {softmod: false, folder: null};

		var remainder:String = path.substr(start);
		if(remainder.length == 0) return {softmod: true, folder: null};
		var slash:Int = remainder.indexOf('/');
		if(slash < 0) return {softmod: true, folder: null};

		var first:String = remainder.substr(0, slash);
		var firstLower:String = first.toLowerCase();
		// These are the recognised loose-content folders, not mod names.
		for(reserved in [
			'characters', 'custom_events', 'custom_notetypes', 'data', 'songs', 'music', 'sounds', 'shaders',
			'videos', 'images', 'stages', 'weeks', 'fonts', 'scripts', 'achievements'
		])
			if(firstLower == reserved) return {softmod: true, folder: null};
		return {softmod: true, folder: first};
	}

	static function normalizePath(path:String):String
	{
		if(path == null) return '';
		var normalized:String = path.split('\\').join('/');
		while(normalized.startsWith('./')) normalized = normalized.substr(2);
		while(normalized.indexOf('//') != -1) normalized = normalized.split('//').join('/');
		return normalized;
	}

	static function displayPath(path:String, folder:Null<String>):String
	{
		if(path == null || path.length == 0) return '<inline script>';
		var lower:String = path.toLowerCase();
		var marker:String = folder == null ? 'mods/' : 'mods/' + folder.toLowerCase() + '/';
		var index:Int = lower.lastIndexOf(marker);
		return index >= 0 ? path.substr(index + marker.length) : path;
	}

	static function emit(message:String, sink:Null<String->Void>):Void
	{
		trace(message);
		if(sink != null) sink(message);
	}
}
