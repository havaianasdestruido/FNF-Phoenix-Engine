package backend;

class Paths
{
  public static function image(key:String, ?library:String):String
    return 'image:' + key;

  public static function font(key:String):String
    return 'font:' + key;

  public static function sound(key:String, ?library:String):String
    return 'sound:' + key;
}
