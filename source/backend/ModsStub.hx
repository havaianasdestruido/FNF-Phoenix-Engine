package backend;

// Always-available no-op stub of backend.Mods for non-MODS_ALLOWED targets.
// Callers can reference Mods.<method> without wrapping in #if MODS_ALLOWED;
// on MODS_ALLOWED builds this is shadowed by the real backend.Mods import in import.hx.
class Mods
{
	static public var currentModDirectory:String = '';
	public static var ignoreModFolders:Array<String> = [];
	/**
	 * Executes the `getGlobalMods` operation.
	 * @return Result produced by `getGlobalMods`, when applicable.
	 */
	inline public static function getGlobalMods():Array<String>
		return [];
	/**
	 * Executes the `pushGlobalMods` operation.
	 * @return Result produced by `pushGlobalMods`, when applicable.
	 */
	inline public static function pushGlobalMods():Array<String>
		return [];
	/**
	 * Executes the `getModDirectories` operation.
	 * @return Result produced by `getModDirectories`, when applicable.
	 */
	inline public static function getModDirectories():Array<String>
		return [];
	/**
	 * Executes the `mergeAllTextsNamed` operation.
	 * @param path Input value for `path`.
	 * @param defaultDirectory Input value for `defaultDirectory`.
	 * @param allowDuplicates Input value for `allowDuplicates`.
	 * @return Result produced by `mergeAllTextsNamed`, when applicable.
	 */
	inline public static function mergeAllTextsNamed(path:String, defaultDirectory:String = null, allowDuplicates:Bool = false):Array<String>
		return [];
	/**
	 * Executes the `directoriesWithFile` operation.
	 * @param path Input value for `path`.
	 * @param fileToFind Input value for `fileToFind`.
	 * @param mods Input value for `mods`.
	 * @return Result produced by `directoriesWithFile`, when applicable.
	 */
	inline public static function directoriesWithFile(path:String, fileToFind:String, mods:Bool = true):Array<String>
		return [];
	/**
	 * Executes the `getPack` operation.
	 * @param folder Input value for `folder`.
	 * @return Result produced by `getPack`, when applicable.
	 */
	inline public static function getPack(?folder:String = null):Dynamic
		return null;
	public static var updatedOnState:Bool = false;
	/**
	 * Executes the `parseList` operation.
	 * @return Result produced by `parseList`, when applicable.
	 */
	inline public static function parseList():ModsList
		return {enabled: [], disabled: [], all: []};
	/**
	 * Executes the `loadTopMod` operation.
	 */
	inline public static function loadTopMod():Void {}
}

typedef ModsList = {
	enabled:Array<String>,
	disabled:Array<String>,
	all:Array<String>
};
