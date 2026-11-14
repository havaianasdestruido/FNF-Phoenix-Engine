package backend;
class LowMemory
{
  public static var experimental:Bool = false;
  public static function policy():Dynamic return {skipSongPreload: experimental};
}
