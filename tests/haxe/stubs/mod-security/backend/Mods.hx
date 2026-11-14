package backend;

/**
 * Stand-in for `backend.Mods` in ModSecurityPlayerSpec: the spec supplies each
 * mod's parsed `pack.json` instead of reading one from a real `mods/` folder.
 */
class Mods
{
	public static var packs:Map<String, Dynamic> = [];

	public static function getPack(?folder:String = null):Dynamic
		return folder != null && packs.exists(folder) ? packs.get(folder) : null;
}
