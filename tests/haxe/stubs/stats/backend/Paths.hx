package backend;

class Paths
{
  public static var storedCleared:Int = 0;
  public static var unusedCleared:Int = 0;

  public static function clearStoredMemory():Void storedCleared++;
  public static function clearUnusedMemory():Void unusedCleared++;
  public static function image(name:String):String return 'images/' + name;
  public static function font(name:String):String return 'fonts/' + name;
  public static function sound(name:String):String return 'sounds/' + name;
  public static function fileExists(key:String, type:Dynamic, ignoreMods:Bool = false):Bool return false;

  public static function reset():Void
  {
    storedCleared = 0;
    unusedCleared = 0;
  }
}
