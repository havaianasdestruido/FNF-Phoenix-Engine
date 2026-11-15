package backend;

class VLog
{
  public static function memoryEvent(message:String):Void {}
  public static function heapUsedBytes():Float return 100;
  public static function formatBytes(bytes:Float):String return Std.string(bytes);
}
