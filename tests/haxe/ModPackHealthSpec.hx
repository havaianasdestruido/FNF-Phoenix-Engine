import backend.ModHealth;
import backend.Mods;
import sys.FileSystem;
import sys.io.File;

using StringTools;

/**
 * `Mods.getPack()` has to report a `pack.json` it cannot use to the Mods menu
 * (§19), not only to the log: a broken manifest is why a mod shows up under its
 * folder name and behaves as if it had no settings.
 *
 * Built with -D MODS_ALLOWED against a small `backend.Paths` double (this spec
 * only needs `Paths.mods()`), and run inside a throwaway working directory so
 * the `mods/` tree it creates never reaches the repository. See
 * run-mod-health.sh.
 */
class ModPackHealthSpec
{
	static inline final ROOT:String = 'mods';

	static var checks:Int = 0;

	static function check(value:Bool, label:String):Void
	{
		checks++;
		if(!value) throw label;
	}

	static function write(folder:String, text:String):Void
	{
		var dir:String = '$ROOT/$folder';
		if(!FileSystem.exists(dir)) FileSystem.createDirectory(dir);
		File.saveContent('$dir/pack.json', text);
	}

	static function main():Void
	{
		haxe.Log.trace = function(value:Dynamic, ?infos:haxe.PosInfos) {};
		removeTree(ROOT);

		// A valid manifest is returned and records nothing.
		write('Good', '{\n  "name": "A good mod",\n  "color": [10, 20, 30],\n}');
		var pack:Dynamic = Mods.getPack('Good');
		check(pack != null && pack.name == 'A good mod', 'a valid manifest parses');
		check(ModHealth.isHealthy('Good'), 'a valid manifest records no problem');
		check(Mods.invalidMods.indexOf('Good') < 0, 'and is not flagged invalid');

		// Comments and trailing commas are fine, as the importer validator promises.
		write('Commented', '// hi\n{"name": "Commented", "restart": true,}');
		check(Mods.getPack('Commented') != null, 'tjson comments and trailing commas still parse');
		check(ModHealth.isHealthy('Commented'), 'and record no problem');

		// A syntax error is reported with the parser's message.
		write('Broken', '{"name": "Broken",,}');
		check(Mods.getPack('Broken') == null, 'a broken manifest reads as null');
		var reason:Null<String> = ModHealth.invalidPackReason('Broken');
		check(reason != null && reason.length > 0, 'the parser reason is recorded');
		check(ModHealth.lines('Broken')[0].indexOf('pack.json could not be used:') == 0,
			'the report leads with the manifest: ' + ModHealth.lines('Broken')[0]);
		check(Mods.invalidMods.contains('Broken'), 'the bad_mod achievement still fires');

		// An array (or an empty file) is not a manifest either.
		write('Array', '[{"name": "not an object"}]');
		check(Mods.getPack('Array') == null, 'an array is not a pack');
		check(ModHealth.invalidPackReason('Array') != null, 'and is reported');

		write('Empty', '');
		check(Mods.getPack('Empty') == null, 'an empty manifest reads as null');
		check(ModHealth.invalidPackReason('Empty') != null, 'and is reported');

		// A mod without pack.json is a normal Psych mod, not a broken one.
		FileSystem.createDirectory('$ROOT/NoManifest');
		check(Mods.getPack('NoManifest') == null, 'no manifest, no pack');
		check(ModHealth.isHealthy('NoManifest'), 'a mod without a manifest is not broken');

		// A valid manifest does not inherit an earlier failure: the record is per read.
		write('Broken', '{"name": "Fixed now"}');
		check(Mods.getPack('Broken') != null, 'the fixed manifest parses');
		check(ModHealth.invalidPackReason('Broken') != null, 'the earlier failure stays on record until it is dropped');
		ModHealth.forget('Broken');
		check(ModHealth.isHealthy('Broken'), 'and forget() drops it, e.g. after a reinstall');

		removeTree(ROOT);
		Sys.println('ModPackHealthSpec: all $checks checks passed');
	}

	static function removeTree(path:String):Void
	{
		if(!FileSystem.exists(path)) return;
		if(FileSystem.isDirectory(path))
		{
			for(entry in FileSystem.readDirectory(path)) removeTree('$path/$entry');
			FileSystem.deleteDirectory(path);
		}
		else FileSystem.deleteFile(path);
	}
}
