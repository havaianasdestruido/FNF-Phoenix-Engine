package backend;

class ClientPrefs
{
  public static var noteOffset:Float = 0;
  public static var noteColorStyle:String = '';
  public static var enableColorShader:Bool = false;

  public static function getGameplaySetting(name:String, defaultValue:Dynamic):Dynamic return defaultValue;
}
