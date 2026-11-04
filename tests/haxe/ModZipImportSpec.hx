// Dependency-free contract tests for the `.zip` mod importer.
//
// Runs with `haxe --interp` (see tests/haxe/run-mod-zip.sh) against copies of
// source/backend/ModPathPolicy.hx and source/mobile/files/ModZipInstaller.hx,
// so no Flixel/OpenFL/haxelib setup is required.
//
// Pinned invariants:
//   * absolute, `..`, Windows-drive, illegal-character and too-deep entries are
//     rejected instead of being rewritten;
//   * a valid mod archive installs into mods/<folder>/, its pack.json is
//     validated and wrapper folders/macOS metadata are handled;
//   * a rejected archive never leaves a partial mod (or staging folder) behind;
//   * an existing folder is only replaced when the caller explicitly asks.
import backend.ModPathPolicy;
import haxe.io.Bytes;
import haxe.io.BytesOutput;
import mobile.files.ModZipInstaller;
import mobile.files.ModZipInstaller.ModZipEntry;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class ModZipImportSpec
{
	static inline final WORK:String = 'mod-zip-spec-work';

	static function check(value:Bool, label:String):Void
	{
		if(!value) throw 'FAILED: $label';
	}

	static function checkThrows(fn:Void->Void, label:String):Void
	{
		var threw:Bool = false;
		try
		{
			fn();
		}
		catch(e:Dynamic)
		{
			threw = true;
		}
		check(threw, label);
	}

	/** Builds a stored (uncompressed) zip; enough to exercise the importer. */
	static function zip(entries:Array<{name:String, data:String}>):Bytes
	{
		var list:haxe.ds.List<haxe.zip.Entry> = new haxe.ds.List();
		for(entry in entries)
		{
			var data:Bytes = Bytes.ofString(entry.data);
			list.add({
				fileName: entry.name,
				fileSize: data.length,
				fileTime: Date.now(),
				compressed: false,
				dataSize: data.length,
				data: data,
				crc32: null
			});
		}

		var output:BytesOutput = new BytesOutput();
		new haxe.zip.Writer(output).write(list);
		return output.getBytes();
	}

	static function resetWorkDirectory():String
	{
		if(FileSystem.exists(WORK)) deleteDirectory(WORK);
		FileSystem.createDirectory(WORK);
		return WORK;
	}

	static function deleteDirectory(path:String):Void
	{
		if(!FileSystem.exists(path)) return;
		if(!FileSystem.isDirectory(path))
		{
			FileSystem.deleteFile(path);
			return;
		}
		for(name in FileSystem.readDirectory(path))
			deleteDirectory(path + '/' + name);
		FileSystem.deleteDirectory(path);
	}

	static function stagingLeftovers(directory:String):Int
	{
		var count:Int = 0;
		for(name in FileSystem.readDirectory(directory))
			if(name.startsWith('.phoenix-import-')) count++;
		return count;
	}

	static function main():Void
	{
		testPathPolicy();
		testLayoutDetection();
		testInstallFromWrapperFolder();
		testInstallFromRootPack();
		testRejectsUnsafeArchives();
		testRejectsInvalidPack();
		testReplacesExistingFolderOnRequest();
		testInspectReportsConflict();

		deleteDirectory(WORK);
		trace('ModZipImportSpec: all checks passed');
	}

	static function testPathPolicy():Void
	{
		check(ModPathPolicy.normalizeRelative('data/song/chart.json') == 'data/song/chart.json', 'relative paths are kept');
		check(ModPathPolicy.normalizeRelative('data/./song//chart.json') == 'data/song/chart.json', 'empty and dot segments collapse');
		check(ModPathPolicy.normalizeRelative('data\\images\\icon.png') == 'data/images/icon.png', 'backslashes normalize');

		check(ModPathPolicy.normalizeRelative('../evil.txt') == null, 'parent traversal rejected');
		check(ModPathPolicy.normalizeRelative('data/../../evil.txt') == null, 'nested traversal rejected');
		check(ModPathPolicy.normalizeRelative('..\\evil.txt') == null, 'windows traversal rejected');
		check(ModPathPolicy.normalizeRelative('/etc/passwd') == null, 'absolute posix path rejected');
		check(ModPathPolicy.normalizeRelative('C:/Windows/system32') == null, 'windows drive path rejected');
		check(ModPathPolicy.normalizeRelative('//server/share/x') == null, 'unc path rejected');
		check(ModPathPolicy.normalizeRelative('') == null, 'empty path rejected');
		check(ModPathPolicy.normalizeRelative('data/bad' + String.fromCharCode(0) + 'name') == null, 'nul byte rejected');
		check(ModPathPolicy.normalizeRelative('data/con/audio.ogg') == null, 'windows device name rejected');
		check(ModPathPolicy.normalizeRelative('data/trailing.') == null, 'trailing dot rejected');
		check(ModPathPolicy.normalizeRelative(repeat('a/', 20) + 'f.txt') == null, 'path depth rejected');
		check(ModPathPolicy.normalizeRelative(repeat('a', 200) + '.txt') == null, 'path length rejected');

		check(ModPathPolicy.sanitizeFolderName('My Mod.zip') == 'My Mod', 'zip extension dropped, spaces kept');
		check(ModPathPolicy.sanitizeFolderName('../../etc/passwd') == 'passwd', 'folder name cannot keep a path');
		check(ModPathPolicy.sanitizeFolderName('images') == 'images_mod', 'reserved asset folder renamed');
		check(ModPathPolicy.sanitizeFolderName('CON') == '_CON', 'windows device name prefixed');
		check(ModPathPolicy.sanitizeFolderName('..') == 'imported_mod', 'empty name falls back');
		check(ModPathPolicy.sanitizeFolderName('bad|name?.zip') == 'bad_name', 'illegal characters replaced');

		check(ModPathPolicy.isSafeFolderName('My Mod'), 'plain folder name accepted');
		check(!ModPathPolicy.isSafeFolderName('a/b'), 'separator rejected in folder name');
		check(!ModPathPolicy.isSafeFolderName('..'), 'traversal rejected in folder name');
		check(!ModPathPolicy.isSafeFolderName('.staging'), 'dot folder rejected');
		check(!ModPathPolicy.isSafeFolderName('data'), 'reserved folder rejected');

		check(ModPathPolicy.resolveInside('mods/', 'a/b.txt') == 'mods/a/b.txt', 'resolve inside keeps base');
		check(ModPathPolicy.resolveInside('mods', '../a.txt') == null, 'resolve inside refuses escapes');
		check(ModPathPolicy.resolveInside('mods/../..', 'a.txt') == null, 'unsafe base refused');
	}

	static function testLayoutDetection():Void
	{
		// __MACOSX entries are dropped before layout detection (see importZip),
		// so this mirrors the filtered list the importer works with.
		var wrapped:Array<ModZipEntry> = entriesFor([
			'MyMod/pack.json',
			'MyMod/data/song.json',
			'README.txt'
		]);
		var layout = ModZipInstaller.resolveLayout(wrapped);
		if(layout == null) throw 'FAILED: wrapper folder detected';
		check(layout.prefix == 'MyMod', 'wrapper folder name used as prefix');
		check(layout.ignored.length == 1, 'top-level README reported as ignored');

		var root:Array<ModZipEntry> = entriesFor(['pack.json', 'data/song.json']);
		var rootLayout = ModZipInstaller.resolveLayout(root);
		if(rootLayout == null) throw 'FAILED: root pack.json needs no prefix';
		check(rootLayout.prefix == '', 'root pack.json needs no prefix');

		var ambiguous:Array<ModZipEntry> = entriesFor(['A/pack.json', 'B/pack.json']);
		check(ModZipInstaller.resolveLayout(ambiguous) == null, 'two candidate mods are ambiguous');

		var missing:Array<ModZipEntry> = entriesFor(['A/data/song.json']);
		check(ModZipInstaller.resolveLayout(missing) == null, 'no pack.json means no mod root');
	}

	static function testInstallFromWrapperFolder():Void
	{
		var directory:String = resetWorkDirectory();
		var archive:Bytes = zip([
			{name: 'MyMod/', data: ''},
			{name: 'MyMod/pack.json', data: '{"name":"My Mod","description":"test"}'},
			{name: 'MyMod/data/song.json', data: '{"song":"test"}'},
			{name: 'MyMod/scripts/', data: ''},
			{name: 'MyMod/scripts/main.lua', data: 'function onCreate() end'},
			{name: 'README.txt', data: 'not part of the mod'},
			{name: '__MACOSX/MyMod/._pack.json', data: 'junk'}
		]);

		var result = ModZipInstaller.importZip(archive, 'whatever.zip', directory);
		check(result.ok, 'wrapper archive installs: ' + result.error);
		check(result.folder == 'MyMod', 'folder taken from the wrapper: ' + result.folder);
		check(result.name == 'My Mod', 'pack.json name reported: ' + result.name);
		check(result.files == 3, 'only mod files are written: ' + result.files);

		check(FileSystem.exists(directory + '/MyMod/pack.json'), 'pack.json extracted');
		check(File.getContent(directory + '/MyMod/pack.json').indexOf('My Mod') >= 0, 'pack.json content preserved');
		check(FileSystem.exists(directory + '/MyMod/data/song.json'), 'nested asset extracted');
		check(FileSystem.isDirectory(directory + '/MyMod/scripts'), 'directory entries created');
		check(File.getContent(directory + '/MyMod/scripts/main.lua').indexOf('onCreate') >= 0, 'script extracted');
		check(!FileSystem.exists(directory + '/MyMod/README.txt'), 'root README skipped');
		check(!FileSystem.exists(directory + '/MyMod/__MACOSX'), 'macOS metadata skipped');
		check(stagingLeftovers(directory) == 0, 'staging folder cleaned up');
	}

	static function testInstallFromRootPack():Void
	{
		var directory:String = resetWorkDirectory();
		var archive:Bytes = zip([
			{name: 'pack.json', data: '{"name":"Cool Mod"}'},
			{name: 'data/song.json', data: '{"song":"test"}'}
		]);

		var result = ModZipInstaller.importZip(archive, 'Cool Mod.zip', directory);
		check(result.ok, 'root pack archive installs: ' + result.error);
		check(result.folder == 'Cool Mod', 'folder derived from the file name: ' + result.folder);
		check(FileSystem.exists(directory + '/Cool Mod/data/song.json'), 'root archive extracted');
	}

	static function testRejectsUnsafeArchives():Void
	{
		var directory:String = resetWorkDirectory();

		var traversal:Bytes = zip([
			{name: 'pack.json', data: '{"name":"Evil"}'},
			{name: '../escaped.txt', data: 'nope'}
		]);
		checkThrows(function() {
			ModZipInstaller.readEntries(traversal);
		}, 'traversal entry rejected by the reader');

		var traversalResult = ModZipInstaller.importZip(traversal, 'evil.zip', directory);
		check(!traversalResult.ok, 'traversal archive not installed');
		check(!FileSystem.exists('escaped.txt'), 'nothing written outside the mod folder');
		check(stagingLeftovers(directory) == 0, 'no staging folder left after a rejection');

		var absolute:Bytes = zip([
			{name: 'pack.json', data: '{"name":"Evil"}'},
			{name: '/tmp/phoenix-absolute.txt', data: 'nope'}
		]);
		check(!ModZipInstaller.importZip(absolute, 'absolute.zip', directory).ok, 'absolute entry rejected');

		var backslash:Bytes = zip([
			{name: 'pack.json', data: '{"name":"Evil"}'},
			{name: '..\\escaped.txt', data: 'nope'}
		]);
		check(!ModZipInstaller.importZip(backslash, 'backslash.zip', directory).ok, 'windows traversal rejected');

		var notAZip:Bytes = Bytes.ofString('these are not the bytes you are looking for');
		check(!ModZipInstaller.importZip(notAZip, 'fake.zip', directory).ok, 'non-zip data rejected');
		check(stagingLeftovers(directory) == 0, 'no staging folder left after a fake archive');
	}

	static function testRejectsInvalidPack():Void
	{
		var directory:String = resetWorkDirectory();

		var noPack:Bytes = zip([{name: 'data/song.json', data: '{}'}]);
		var noPackResult = ModZipInstaller.importZip(noPack, 'no-pack.zip', directory);
		check(!noPackResult.ok, 'archive without pack.json rejected');
		check(!FileSystem.exists(directory + '/no-pack'), 'no mod folder created');
		check(stagingLeftovers(directory) == 0, 'staging removed');

		var broken:Bytes = zip([{name: 'pack.json', data: '{this is not json'}]);
		check(!ModZipInstaller.importZip(broken, 'broken.zip', directory).ok, 'invalid pack.json rejected');

		var arrayPack:Bytes = zip([{name: 'pack.json', data: '[1,2,3]'}]);
		check(!ModZipInstaller.importZip(arrayPack, 'array.zip', directory).ok, 'non-object pack.json rejected');

		var good:Bytes = zip([{name: 'pack.json', data: '{"name":"Rejected by validator"}'}]);
		var custom = ModZipInstaller.importZip(good, 'custom.zip', directory, null, function(text:String) return false);
		check(!custom.ok, 'custom validator can reject a mod');
		check(stagingLeftovers(directory) == 0, 'staging removed after validation failure');
	}

	static function testReplacesExistingFolderOnRequest():Void
	{
		var directory:String = resetWorkDirectory();
		var first:Bytes = zip([
			{name: 'pack.json', data: '{"name":"v1"}'},
			{name: 'data/v1.txt', data: 'old'}
		]);
		check(ModZipInstaller.importZip(first, 'SameMod.zip', directory).ok, 'first install succeeds');

		var second:Bytes = zip([
			{name: 'pack.json', data: '{"name":"v2"}'},
			{name: 'data/v2.txt', data: 'new'}
		]);
		var conflict = ModZipInstaller.importZip(second, 'SameMod.zip', directory);
		check(!conflict.ok, 'second install refuses to overwrite by default');
		check(conflict.error.indexOf('already installed') >= 0, 'conflict error explains the clash');
		check(FileSystem.exists(directory + '/SameMod/data/v1.txt'), 'refused import keeps the installed mod');

		var replaced = ModZipInstaller.importZip(second, 'SameMod.zip', directory, null, null, true);
		check(replaced.ok, 'explicit replace succeeds: ' + replaced.error);
		check(FileSystem.exists(directory + '/SameMod/data/v2.txt'), 'replacement content installed');
		check(!FileSystem.exists(directory + '/SameMod/data/v1.txt'), 'replacement drops the old files');
		check(stagingLeftovers(directory) == 0, 'staging cleaned up after a replace');
	}

	static function testInspectReportsConflict():Void
	{
		var directory:String = resetWorkDirectory();
		var archive:Bytes = zip([{name: 'pack.json', data: '{"name":"Once"}'}]);

		var before = ModZipInstaller.inspect(archive, 'Once.zip', directory);
		check(before.ok, 'inspect accepts a valid archive: ' + before.error);
		check(!before.conflicts, 'inspect reports no conflict before install');

		check(ModZipInstaller.importZip(archive, 'Once.zip', directory).ok, 'install for inspect test');
		var after = ModZipInstaller.inspect(archive, 'Once.zip', directory);
		check(after.ok, 'inspect still accepts the archive');
		check(after.conflicts, 'inspect reports the conflict afterwards');

		var invalid = ModZipInstaller.inspect(Bytes.ofString('nope'), 'broken.zip', directory);
		check(!invalid.ok && invalid.error.length > 0, 'inspect explains invalid archives');
	}

	// ------------------------------------------------------------------

	static function entriesFor(paths:Array<String>):Array<ModZipEntry>
	{
		var list:Array<ModZipEntry> = [];
		for(path in paths)
		{
			var normalized:Null<String> = ModPathPolicy.normalizeRelative(path);
			if(normalized == null) continue;

			list.push({
				name: path,
				path: normalized,
				directory: path.endsWith('/'),
				compression: 0,
				compressedSize: 0,
				uncompressedSize: 0,
				localOffset: 0
			});
		}
		return list;
	}

	static function repeat(value:String, times:Int):String
	{
		var result:String = '';
		for(i in 0...times) result += value;
		return result;
	}
}
