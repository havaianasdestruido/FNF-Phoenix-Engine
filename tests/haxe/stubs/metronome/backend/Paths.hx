package backend;

class Paths
{
  public static var lookups:Int = 0;

  public static function sound(key:String):String
  {
    lookups++;
    return key;
  }
}
