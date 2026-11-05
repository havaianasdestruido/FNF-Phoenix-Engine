package backend;
// Minimal stand-in for backend.Mods: only the fields Paths.modFolders reads.
class Mods {
  public static var currentModDirectory:String = '';
  public static var ignoreModFolders:Array<String> = [];
  public static var globalMods:Array<String> = [];
  public static function getGlobalMods():Array<String> return globalMods;
}
