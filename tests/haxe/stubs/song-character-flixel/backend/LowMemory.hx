package backend;
class LowMemory
{
  public static var experimental:Bool = false;
  public static function experimentalHudOnly():Bool return experimental && !ClientPrefs.charsAndBG;
}
