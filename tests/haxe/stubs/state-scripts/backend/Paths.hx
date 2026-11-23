package backend;

/**
 * Fixture-rooted stand-in for the asset resolver. Tests point `root` at a
 * directory tree they built themselves and get deterministic lookups.
 */
class Paths
{
  public static var root:String = '';

  public static function getPreloadPath(rest:String):String
    return root + 'game/' + rest;

  public static function mods(path:String):String
    return root + 'mods/' + path;
}
