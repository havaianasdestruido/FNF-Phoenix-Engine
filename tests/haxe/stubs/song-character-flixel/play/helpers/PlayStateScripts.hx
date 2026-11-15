package play.helpers;
class PlayStateScripts
{
  public static var unsupportedCharacterCalls:Int = 0;
  public static function noteUnsupportedLua(path:String):Void unsupportedCharacterCalls++;
}
