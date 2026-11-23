package backend;

/** Settable stand-in for the mod list. */
class Mods
{
  public static var globalMods:Array<String> = [];
  public static var currentModDirectory:Null<String> = null;

  public static function reset():Void
  {
    globalMods = [];
    currentModDirectory = null;
  }

  public static function getGlobalMods():Array<String>
    return globalMods.copy();
}
