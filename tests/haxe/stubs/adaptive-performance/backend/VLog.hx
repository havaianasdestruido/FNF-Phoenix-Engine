package backend;
class VLog
{
  public static var events:Array<String> = [];
  public static function memoryEvent(message:String):Void events.push(message);
}
