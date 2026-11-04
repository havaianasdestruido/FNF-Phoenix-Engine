package backend;

/** Log stand-in: an in-memory tail, plus a switch to simulate an unreadable log. */
class VLog
{
  public static inline var FILE:String = "vlog/log.txt";
  public static var enabled:Bool = false;
  public static var active:Bool = false;
  public static var heapBytes:Float = 234881024;   // 224 MB
  public static var lines:Array<String> = [];
  /** When set, the report must degrade to an `unavailable:` row instead of throwing. */
  public static var failNext:Bool = false;

  public static function isActive():Bool
  {
    if (failNext) throw 'simulated storage failure';
    return active;
  }

  public static function heapUsedBytes():Float
    return heapBytes;

  public static function exportText():String
    return lines.join('\n');

  public static function formatBytes(bytes:Float):String
    return (bytes < 0.0) ? 'n/a' : '${Std.int(bytes / 1024 / 1024)}MB';
}
