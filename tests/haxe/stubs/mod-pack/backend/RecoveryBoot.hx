package backend;

/** `backend.RecoveryBoot` double: the spec is not a recovery boot. */
class RecoveryBoot
{
	public static var disableMods:Bool = false;
	public static function modsDisabled():Bool
		return disableMods;
	public static function disabledModsPath():String
		return 'mods/';
}
