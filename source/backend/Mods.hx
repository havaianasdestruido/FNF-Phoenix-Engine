package backend;

import backend.CoolUtil;
import haxe.Json;

class Mods
{
	static public var currentModDirectory:String = '';

	/**
	 * Folders under `mods/` that hold loose shared assets instead of a mod.
	 * Kept in sync with `ModPathPolicy.RESERVED_MOD_FOLDERS`, which the mod
	 * importer also uses to reject colliding folder names.
	 */
	public static var ignoreModFolders:Array<String> = ModPathPolicy.RESERVED_MOD_FOLDERS.copy();

	private static var globalMods:Array<String> = [];

	/**
	 * Folders of mods that were installed but whose data couldn't be parsed
	 * (invalid `pack.json`, broken `achievements.json`, ...).
	 * Used by the `bad_mod` achievement.
	 */
	public static var invalidMods:Array<String> = [];

	inline public static function getGlobalMods()
		return globalMods;

	/**
	 * Registers a mod folder that contains invalid data and awards the `bad_mod` achievement.
	 * @param folder Mod folder, defaults to the currently loaded mod.
	 */
	public static function markInvalidMod(?folder:String = null):Void
	{
		if(folder == null) folder = currentModDirectory;
		if(folder == null) folder = '';

		if(invalidMods.contains(folder)) return;

		invalidMods.push(folder);
		trace('Mod "$folder" has invalid data.');

		#if ACHIEVEMENTS_ALLOWED
		if(Achievements.exists('bad_mod')) Achievements.unlock('bad_mod');
		#end
	}

	inline public static function pushGlobalMods() // prob a better way to do this but idc
	{
		globalMods = [];
		for(mod in parseList().enabled)
		{
			var pack:Dynamic = getPack(mod);
			if(pack != null && pack.runsGlobally) globalMods.push(mod);
		}
		Paths.invalidateAssetLookupCache();
		return globalMods;
	}

	inline public static function getModDirectories():Array<String>
	{
		var list:Array<String> = [];
		#if MODS_ALLOWED
		var modsFolder:String = Paths.mods();
		if(FileSystem.exists(modsFolder)) {
			for (folder in FileSystem.readDirectory(modsFolder))
			{
				// Dot folders are engine scratch space (see ModZipInstaller's
				// staging directory) and are never installable mods.
				if (folder.startsWith('.')) continue;

				var path = haxe.io.Path.join([modsFolder, folder]);
				if (FileSystem.isDirectory(path) && !ignoreModFolders.contains(folder.toLowerCase()) && !list.contains(folder))
					list.push(folder);
			}
		}
		#end
		return list;
	}
	
	inline public static function mergeAllTextsNamed(path:String, defaultDirectory:String = null, allowDuplicates:Bool = false)
	{
		if(defaultDirectory == null) defaultDirectory = Paths.getSharedPath();
		defaultDirectory = defaultDirectory.trim();
		if(!defaultDirectory.endsWith('/')) defaultDirectory += '/';
		if(!defaultDirectory.startsWith('assets/')) defaultDirectory = 'assets/$defaultDirectory';

		var mergedList:Array<String> = [];
		var paths:Array<String> = directoriesWithFile(defaultDirectory, path);

		var defaultPath:String = defaultDirectory + path;
		if(paths.contains(defaultPath))
		{
			paths.remove(defaultPath);
			paths.insert(0, defaultPath);
		}

		for (file in paths)
		{
			var list:Array<String> = CoolUtil.coolTextFile(file);
			for (value in list)
				if((allowDuplicates || !mergedList.contains(value)) && value.length > 0)
					mergedList.push(value);
		}
		return mergedList;
	}

	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true)
	{
		var foldersToCheck:Array<String> = [];
		#if sys
		if(FileSystem.exists(path + fileToFind))
		#end
			foldersToCheck.push(path + fileToFind);

		#if MODS_ALLOWED
		if(mods)
		{
			// Global mods first
			for(mod in Mods.getGlobalMods())
			{
				var folder:String = Paths.mods(mod + '/' + fileToFind);
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}

			// Then "PsychEngine/mods/" main folder
			var folder:String = Paths.mods(fileToFind);
			if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(Paths.mods(fileToFind));

			// And lastly, the loaded mod's folder
			if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			{
				var folder:String = Paths.mods(Mods.currentModDirectory + '/' + fileToFind);
				if(FileSystem.exists(folder) && !foldersToCheck.contains(folder)) foldersToCheck.push(folder);
			}
		}
		#end
		return foldersToCheck;
	}

	public static function getPack(?folder:String = null):Dynamic
	{
		#if MODS_ALLOWED
		if(folder == null) folder = Mods.currentModDirectory;

		var path = Paths.mods(folder + '/pack.json');
		if(FileSystem.exists(path)) {
			try {
				#if sys
				var rawJson:String = File.getContent(path);
				#else
				var rawJson:String = Assets.getText(path);
				#end
				if(rawJson != null && rawJson.length > 0) return tjson.TJSON.parse(rawJson);
			} catch(e:Dynamic) {
				trace(e);
				markInvalidMod(folder);
			}
		}
		#end
		return null;
	}

	public static var updatedOnState:Bool = false;
	inline public static function parseList():ModsList {
		if(!updatedOnState) updateModList();
		var list:ModsList = {enabled: [], disabled: [], all: []};

		#if MODS_ALLOWED
		try {
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				//trace('Mod: $mod');
				if(mod.trim().length < 1) continue;

				var dat = mod.split("|");
				list.all.push(dat[0]);
				if (dat[1] == "1")
					list.enabled.push(dat[0]);
				else
					list.disabled.push(dat[0]);
			}
		} catch(e) {
			trace(e);
		}
		#end
		return list;
	}

	/**
	 * Enables a freshly imported mod folder in `modsList.txt`.
	 *
	 * The list keeps its current order: an existing entry only gets its enabled
	 * flag updated, and a new folder is appended. The cached list is invalidated
	 * so the next `parseList()` rescans the `mods/` folder.
	 *
	 * Used by the "Import mod (.zip)" flow in `ModsMenuState`; the name must
	 * already be sanitized (`ModPathPolicy`).
	 *
	 * @param folder folder name under `mods/`
	 * @param enabled whether the mod starts enabled
	 * @return false when the name is unsafe or `modsList.txt` could not be written
	 */
	public static function registerInstalledMod(folder:String, enabled:Bool = true):Bool
	{
		if(!ModPathPolicy.isSafeFolderName(folder)) return false;

		#if MODS_ALLOWED
		var flag:String = enabled ? '1' : '0';
		try {
			var lines:Array<String> = [];
			var found:Bool = false;
			var existing:Array<String> = [];
			try {
				existing = CoolUtil.coolTextFile('modsList.txt');
			} catch(e:Dynamic) {}

			for (line in existing)
			{
				var entry:String = line.trim();
				if(entry.length < 1) continue;

				var separator:Int = entry.indexOf('|');
				var name:String = separator < 0 ? entry : entry.substr(0, separator).trim();
				if(name == folder)
				{
					lines.push(folder + '|' + flag);
					found = true;
				}
				else lines.push(entry);
			}

			if(!found) lines.push(folder + '|' + flag);

			File.saveContent('modsList.txt', lines.join('\n'));
			updatedOnState = false;
			Paths.invalidateAssetLookupCache();
			return true;
		} catch(e:Dynamic) {
			trace('Could not enable the installed mod "$folder": $e');
			return false;
		}
		#else
		return false;
		#end
	}

	private static function updateModList()
	{
		#if MODS_ALLOWED
		// Find all that are already ordered
		var list:Array<Array<Dynamic>> = [];
		var added:Array<String> = [];
		try {
			for (mod in CoolUtil.coolTextFile('modsList.txt'))
			{
				var dat:Array<String> = mod.split("|");
				var folder:String = dat[0];
				if(folder.trim().length > 0 && !folder.startsWith('.') && FileSystem.exists(Paths.mods(folder))
					&& FileSystem.isDirectory(Paths.mods(folder)) && !added.contains(folder))
				{
					added.push(folder);
					list.push([folder, (dat[1] == "1")]);
				}
			}
		} catch(e) {
			trace(e);
		}
		
		// Scan for folders that aren't on modsList.txt yet
		for (folder in getModDirectories())
		{
			if(folder.trim().length > 0 && FileSystem.exists(Paths.mods(folder)) && FileSystem.isDirectory(Paths.mods(folder)) &&
			!ignoreModFolders.contains(folder.toLowerCase()) && !added.contains(folder))
			{
				added.push(folder);
				list.push([folder, true]); //i like it false by default. -bb //Well, i like it True! -Shadow Mario (2022)
				//Shadow Mario (2023): What the fuck was bb thinking
			}
		}

		// Now save file
		var fileStr:String = '';
		for (values in list)
		{
			if(fileStr.length > 0) fileStr += '\n';
			fileStr += values[0] + '|' + (values[1] ? '1' : '0');
		}

		File.saveContent('modsList.txt', fileStr);
		updatedOnState = true;
		//trace('Saved modsList.txt');
		#end
	}

	public static function loadTopMod()
	{
		Mods.currentModDirectory = '';
		
		#if MODS_ALLOWED
		var list:Array<String> = Mods.parseList().enabled;
		if(list != null && list[0] != null)
			Mods.currentModDirectory = list[0];
		#end
		Paths.invalidateAssetLookupCache();
	}
}