package backend;

class Paths
{
  public static var images:Array<String> = [];
  public static var fonts:Array<String> = [];

  public static function image(key:String, ?library:String):String
  {
    images.push(key);
    return 'image:' + key;
  }

  public static function font(key:String):String
  {
    fonts.push(key);
    return 'font:' + key;
  }
}
