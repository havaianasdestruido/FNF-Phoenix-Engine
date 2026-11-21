package backend;

/**
 * `backend.Paths` double for `ModPackHealthSpec`: only `Mods.getPack()` runs, and
 * it resolves manifests through `Paths.mods()`.
 */
class Paths
{
	public static function mods(key:String = ''):String
		return 'mods/' + key;

	public static function getSharedPath():String
		return 'mods/';

	public static function invalidateAssetLookupCache():Void {}
}
