// Regression test for the mods-menu icon / mod-details loading bug.
//
// `ModItem` (states/ModsMenuState.hx) loads a mod's icon with
// `Paths.cacheBitmap(Paths.mods('$folder/pack.png'))`, i.e. a key that already
// starts with `mods/`. This fork's `cacheBitmap` resolves keys through
// `getPath(key, IMAGE, null, true)` -> `modFolders(key)`, which used to prepend
// the mods root *again*, producing `mods/mods/<folder>/pack.png` (never exists)
// and then falling back to `assets/mods/<folder>/pack.png` (also never exists).
// The result: every mod's icon silently fell back to the `unknownMod`
// placeholder in both the mods list and the details panel.
//
// The fix makes `modFolders` return an already-qualified `mods/...` key
// unchanged. This spec runs the REAL backend/Paths.hx in the interpreter (see
// tests/haxe/run-mod-icon-path.sh) against a throwaway mods/ tree and tiny
// dependency stubs, so no Flixel/OpenFL/haxelib setup is required.
//
// Pinned invariants:
//   * a `mods/<folder>/pack.png` key resolves to itself, never `mods/mods/...`;
//   * `cacheBitmap` loads an existing pack.png / pack-pixel.png and returns null
//     for a mod with no icon (so ModItem can fall back to the placeholder);
//   * normal asset resolution (current mod -> global mods -> mods/ root) is
//     unchanged, including current-mod priority over global mods.
import backend.Mods;
import backend.Paths;
import openfl.utils.AssetType;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class ModIconPathSpec
{
	static function check(value:Bool, label:String):Void
	{
		if(!value) throw 'FAILED: $label';
	}

	static function writeFile(path:String, content:String = 'x'):Void
	{
		var dir:String = haxe.io.Path.directory(path);
		if(dir.length > 0 && !FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		File.saveContent(path, content);
	}

	static function deleteTree(path:String):Void
	{
		if(!FileSystem.exists(path)) return;
		if(FileSystem.isDirectory(path))
		{
			for(entry in FileSystem.readDirectory(path))
				deleteTree(path + '/' + entry);
			FileSystem.deleteDirectory(path);
		}
		else FileSystem.deleteFile(path);
	}

	static function main():Void
	{
		// The runner cds into a throwaway work dir, so build the tree in CWD.
		deleteTree('mods');
		FileSystem.createDirectory('mods');

		try
		{
			run();
		}
		catch(e:Dynamic)
		{
			deleteTree('mods');
			throw e;
		}
		deleteTree('mods');
		trace('ModIconPathSpec: all checks passed');
	}

	static function run():Void
	{
		// --- mods with and without icons -----------------------------------
		writeFile('mods/iconmod/pack.png');
		writeFile('mods/pixelmod/pack-pixel.png');
		FileSystem.createDirectory('mods/noiconmod');

		Mods.currentModDirectory = '';
		Mods.globalMods = [];

		// The exact key shape ModItem uses for the icon.
		var iconKey:String = Paths.mods('iconmod/pack.png');
		check(iconKey == 'mods/iconmod/pack.png', 'Paths.mods builds a mods/-qualified key');

		// modFolders must not double-prefix an already-qualified path, whether
		// or not the file exists.
		check(Paths.modFolders('mods/iconmod/pack.png') == 'mods/iconmod/pack.png',
			'modFolders returns an existing mods/ path unchanged');
		check(Paths.modFolders('mods/ghost/pack.png') == 'mods/ghost/pack.png',
			'modFolders returns a missing mods/ path unchanged (no mods/mods/)');
		check(!Paths.modFolders('mods/iconmod/pack.png').startsWith('mods/mods/'),
			'modFolders never produces mods/mods/');

		// getPath resolves the icon to the real file, not assets/mods/...
		check(Paths.getPath(iconKey, IMAGE, null, true) == 'mods/iconmod/pack.png',
			'getPath resolves pack.png to the mod file');

		// cacheBitmap loads the icon (non-null) so ModItem shows it instead of
		// the unknownMod placeholder.
		check(Paths.cacheBitmap(Paths.mods('iconmod/pack.png')) != null,
			'cacheBitmap loads an existing pack.png');
		check(Paths.cacheBitmap(Paths.mods('pixelmod/pack-pixel.png')) != null,
			'cacheBitmap loads an existing pack-pixel.png');
		check(Paths.cacheBitmap(Paths.mods('noiconmod/pack.png')) == null,
			'cacheBitmap returns null for a mod with no icon (placeholder fallback)');
		check(Paths.cacheBitmap(Paths.mods('noiconmod/pack-pixel.png')) == null,
			'cacheBitmap returns null for a missing pack-pixel.png');

		// --- normal asset resolution is unchanged --------------------------
		writeFile('mods/curmod/images/foo.png');
		writeFile('mods/globalmod/images/bar.png');
		writeFile('mods/images/baz.png');
		writeFile('mods/curmod/images/dup.png');
		writeFile('mods/globalmod/images/dup.png');

		// Current mod wins for a relative key.
		Mods.currentModDirectory = 'curmod';
		Mods.globalMods = [];
		check(Paths.modFolders('images/foo.png') == 'mods/curmod/images/foo.png',
			'relative key resolves inside the current mod');
		check(Paths.getPath('images/foo.png', IMAGE, null, true) == 'mods/curmod/images/foo.png',
			'getPath resolves a relative key inside the current mod');

		// Global mods are consulted when there is no current mod.
		Mods.currentModDirectory = '';
		Mods.globalMods = ['globalmod'];
		check(Paths.modFolders('images/bar.png') == 'mods/globalmod/images/bar.png',
			'relative key resolves inside a global mod');

		// Current mod takes priority over a global mod for the same key.
		Mods.currentModDirectory = 'curmod';
		Mods.globalMods = ['globalmod'];
		check(Paths.modFolders('images/dup.png') == 'mods/curmod/images/dup.png',
			'current mod wins over a global mod');

		// Falls back to the shared mods/ root when no mod owns the key.
		Mods.currentModDirectory = '';
		Mods.globalMods = [];
		check(Paths.modFolders('images/baz.png') == 'mods/images/baz.png',
			'relative key falls back to the mods/ root');

		// A relative key that exists nowhere still gets the mods/ root prefix
		// (callers then fall back to the engine asset libraries).
		check(Paths.modFolders('images/nowhere.png') == 'mods/images/nowhere.png',
			'unowned relative key keeps the single mods/ prefix');
	}
}
