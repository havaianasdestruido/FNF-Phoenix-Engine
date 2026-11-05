// Dependency-free contract tests for the crash-bundle zip writer.
//
// Runs with `haxe --interp` (see tests/haxe/run-crash-bundle.sh) against copies
// of source/backend/CrashBundleWriter.hx and source/backend/ModPathPolicy.hx,
// so no Flixel/OpenFL/haxelib setup is required.
//
// Pinned invariants:
//   * the archive is a valid zip whose entries round-trip (text deflated,
//     media stored) and whose bundle.json manifest lists every kept file;
//   * unsafe, duplicate and oversized entries are skipped and reported, never
//     written and never fatal;
//   * writing is atomic (no leftover .tmp), colliding names get a suffix, and
//     old bundles are pruned to MAX_BUNDLES_KEPT.
import backend.CrashBundleWriter;
import backend.CrashBundleWriter.CrashBundleFile;
import haxe.io.Bytes;
import haxe.io.BytesInput;
import sys.FileSystem;
import sys.io.File;

using StringTools;

class CrashBundleSpec
{
	static inline final WORK:String = 'crash-bundle-spec-work';

	static function check(value:Bool, label:String):Void
	{
		if (!value)
			throw 'FAILED: $label';
	}

	/** Reads an archive back into {name, text, compressed} records. */
	static function readArchive(bytes:Bytes):Array<{name:String, text:String, compressed:Bool}>
	{
		var reader:haxe.zip.Reader = new haxe.zip.Reader(new BytesInput(bytes));
		var out:Array<{name:String, text:String, compressed:Bool}> = [];
		for (entry in reader.read())
		{
			var wasCompressed:Bool = entry.compressed;
			var data:Bytes = haxe.zip.Reader.unzip(entry);
			out.push({name: entry.fileName, text: data.toString(), compressed: wasCompressed});
		}
		return out;
	}

	static function find(entries:Array<{name:String, text:String, compressed:Bool}>, name:String):Null<{name:String, text:String, compressed:Bool}>
	{
		for (entry in entries)
			if (entry.name == name)
				return entry;
		return null;
	}

	static function file(name:String, text:String):CrashBundleFile
		return {name: name, data: Bytes.ofString(text)};

	static function resetWork():String
	{
		if (FileSystem.exists(WORK))
			deleteDirectory(WORK);
		FileSystem.createDirectory(WORK);
		return WORK;
	}

	static function deleteDirectory(path:String):Void
	{
		if (!FileSystem.exists(path))
			return;
		if (!FileSystem.isDirectory(path))
		{
			FileSystem.deleteFile(path);
			return;
		}
		for (name in FileSystem.readDirectory(path))
			deleteDirectory(path + '/' + name);
		FileSystem.deleteDirectory(path);
	}

	// ------------------------------------------------------------------

	static function testRoundTrip():Void
	{
		var files:Array<CrashBundleFile> = [
			file('crash.txt', 'Uncaught Error: null reference\nstack...'),
			file('modsList.txt', 'cool-mod|1\nother-mod|0'),
			file('mods/cool-mod/pack.json', '{"name":"Cool Mod","runsGlobally":false}'),
			file('prefs.json', '{"format":"phoenix-settings-backup"}'),
			{name: 'screenshot.png', data: Bytes.ofString('not-really-a-png-but-bytes')}
		];
		var built:CrashBundleBuild = CrashBundleWriter.build(files, {engine: 'Phoenix Engine 0.0.1', target: 'test'});
		check(built.bytes.length > 0, 'archive has bytes');
		check(built.skipped.length == 0, 'nothing skipped on a clean bundle');

		var entries = readArchive(built.bytes);
		check(entries.length == files.length + 1, 'manifest + every file is present');

		var manifest = find(entries, 'bundle.json');
		check(manifest != null, 'manifest exists');
		var parsed:Dynamic = haxe.Json.parse(manifest.text);
		check(parsed.format == CrashBundleWriter.FORMAT_ID, 'manifest format marker');
		check(parsed.formatVersion == CrashBundleWriter.FORMAT_VERSION, 'manifest format version');
		check(parsed.engine == 'Phoenix Engine 0.0.1', 'manifest carries caller info');
		check(parsed.target == 'test', 'manifest carries target');
		check(parsed.files.length == entries.length, 'manifest lists every entry incl. itself');
		check(parsed.files[0].name == 'bundle.json', 'manifest lists itself first');
		check(parsed.files[0].bytes == manifest.text.length, 'manifest self-size matches its encoded length');

		check(find(entries, 'crash.txt').text == 'Uncaught Error: null reference\nstack...', 'crash text round-trips');
		check(find(entries, 'mods/cool-mod/pack.json').text == '{"name":"Cool Mod","runsGlobally":false}', 'pack.json round-trips');
		check(find(entries, 'screenshot.png').text == 'not-really-a-png-but-bytes', 'screenshot round-trips');

		// Text is deflated; already-compressed media is stored.
		check(find(entries, 'crash.txt').compressed, 'text entries are deflated');
		check(!find(entries, 'screenshot.png').compressed, 'png entries are stored');
	}

	static function testManifestCannotBeSpoofed():Void
	{
		var built = CrashBundleWriter.build([file('crash.txt', 'x')], {format: 'evil', formatVersion: 999});
		var manifest = find(readArchive(built.bytes), 'bundle.json');
		var parsed:Dynamic = haxe.Json.parse(manifest.text);
		check(parsed.format == CrashBundleWriter.FORMAT_ID, 'caller cannot override the format marker');
		check(parsed.formatVersion == CrashBundleWriter.FORMAT_VERSION, 'caller cannot override the format version');
	}

	static function testUnsafeNamesSkipped():Void
	{
		var files:Array<CrashBundleFile> = [
			file('../evil.txt', 'escape'),
			file('/absolute.txt', 'absolute'),
			file('C:\\windows\\evil.txt', 'drive'),
			file('mods/../../secret.txt', 'traversal'),
			file('crash.txt', 'safe')
		];
		var built = CrashBundleWriter.build(files);
		var entries = readArchive(built.bytes);
		check(find(entries, 'crash.txt') != null, 'the safe entry survives');
		check(find(entries, '../evil.txt') == null, 'traversal entry is not written');
		check(find(entries, '/absolute.txt') == null, 'absolute entry is not written');
		check(built.skipped.length == 4, 'every unsafe entry is reported');
	}

	static function testDuplicatesSkipped():Void
	{
		var built = CrashBundleWriter.build([file('crash.txt', 'first'), file('CRASH.TXT', 'second')]);
		var entries = readArchive(built.bytes);
		check(find(entries, 'crash.txt').text == 'first', 'first entry wins');
		check(built.skipped.length == 1, 'duplicate reported');
	}

	static function testOversizedEntrySkipped():Void
	{
		var big:CrashBundleFile = {name: 'huge.txt', data: Bytes.alloc(CrashBundleWriter.MAX_ENTRY_BYTES + 1)};
		var built = CrashBundleWriter.build([big, file('crash.txt', 'ok')]);
		var entries = readArchive(built.bytes);
		check(find(entries, 'huge.txt') == null, 'oversized entry is not written');
		check(find(entries, 'crash.txt') != null, 'the rest of the bundle survives');
		check(built.skipped.length == 1, 'oversized entry reported');
	}

	static function testEntryCountCap():Void
	{
		var files:Array<CrashBundleFile> = [];
		for (i in 0...CrashBundleWriter.MAX_ENTRY_COUNT + 10)
			files.push(file('mods/mod-$i/pack.json', '{}'));
		var built = CrashBundleWriter.build(files);
		var entries = readArchive(built.bytes);
		check(entries.length <= CrashBundleWriter.MAX_ENTRY_COUNT, 'entry count is capped (manifest included)');
		check(built.skipped.length >= 10, 'overflow entries are reported');
	}

	static function testEmptyInputStillValid():Void
	{
		var built = CrashBundleWriter.build(null);
		var entries = readArchive(built.bytes);
		check(entries.length == 1 && entries[0].name == 'bundle.json', 'null input yields a manifest-only archive');
	}

	static function testWriteAndPrune():Void
	{
		var dir:String = resetWork() + '/crash';
		var stamps:Array<Date> = [
			new Date(2026, 0, 1, 0, 0, 0),
			new Date(2026, 0, 2, 0, 0, 0),
			new Date(2026, 0, 3, 0, 0, 0),
			new Date(2026, 0, 4, 0, 0, 0),
			new Date(2026, 0, 5, 0, 0, 0)
		];
		var lastName:String = '';
		for (stamp in stamps)
		{
			var result:CrashBundleWriteResult = CrashBundleWriter.write(dir, [file('crash.txt', 'x')], null, stamp);
			check(result.ok, 'write succeeds');
			check(result.path.endsWith('.zip'), 'bundle is a .zip');
			check(result.files == 2 && result.bytes > 0, 'write reports files and size');
			check(FileSystem.exists(result.path), 'bundle exists on disk');
			lastName = result.path;
		}

		var kept:Array<String> = [];
		for (name in FileSystem.readDirectory(dir))
		{
			check(!name.endsWith('.tmp'), 'no leftover temp file: $name');
			if (name.startsWith(CrashBundleWriter.BUNDLE_PREFIX) && name.endsWith('.zip'))
				kept.push(name);
		}
		check(kept.length == CrashBundleWriter.MAX_BUNDLES_KEPT, 'old bundles are pruned to the keep limit');
		kept.sort(Reflect.compare);
		check(dir + '/' + kept[kept.length - 1] == lastName, 'the newest bundle is the one just written');
		check(!FileSystem.exists(dir + '/' + CrashBundleWriter.fileName(stamps[0])), 'the oldest bundle was pruned');
	}

	static function testCollidingNames():Void
	{
		var dir:String = resetWork() + '/crash';
		var stamp:Date = new Date(2026, 0, 1, 12, 0, 0);
		var first = CrashBundleWriter.writeBytes(dir, Bytes.ofString('first-archive'), stamp);
		var second = CrashBundleWriter.writeBytes(dir, Bytes.ofString('second-archive'), stamp);
		check(first.ok && second.ok, 'both writes succeed');
		check(first.path != second.path, 'colliding names get a suffix');
		check(second.path.endsWith('-2.zip'), 'second bundle is suffixed -2');
		check(FileSystem.exists(first.path) && FileSystem.exists(second.path), 'both bundles exist');
	}

	static function testWriteFailureIsReported():Void
	{
		var empty = CrashBundleWriter.writeBytes(resetWork() + '/crash', null);
		check(!empty.ok && empty.error.length > 0, 'null bytes fail with a reason');

		var notADir:String = resetWork() + '/a-file';
		File.saveContent(notADir, 'x');
		var blocked = CrashBundleWriter.writeBytes(notADir, Bytes.ofString('archive'));
		check(!blocked.ok && blocked.error.length > 0, 'a non-directory target fails with a reason');
	}

	static function testFileName():Void
	{
		var name:String = CrashBundleWriter.fileName(new Date(2026, 10, 4, 21, 55, 3));
		check(name == CrashBundleWriter.BUNDLE_PREFIX + '2026-11-04_21-55-03.zip', 'file name is a sortable timestamp: $name');
	}

	static function main():Void
	{
		testRoundTrip();
		testManifestCannotBeSpoofed();
		testUnsafeNamesSkipped();
		testDuplicatesSkipped();
		testOversizedEntrySkipped();
		testEntryCountCap();
		testEmptyInputStillValid();
		testWriteAndPrune();
		testCollidingNames();
		testWriteFailureIsReported();
		testFileName();
		if (FileSystem.exists(WORK))
			deleteDirectory(WORK);
		Sys.println('CrashBundleSpec: all checks passed.');
	}
}
