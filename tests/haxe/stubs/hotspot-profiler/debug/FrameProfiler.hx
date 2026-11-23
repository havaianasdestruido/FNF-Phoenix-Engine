package debug;

/**
 * Stand-in for the heavy FrameProfiler module: a flag plus a scripted heap
 * readout queue. `queryHeapUsedBytes` returns -1 (meaning "heap unknown")
 * once the queue is drained, so tests opt into heap accounting explicitly.
 */
class FrameProfiler
{
  public static var enabled:Bool = false;

  static var heapScript:Array<Float> = [];

  public static function setHeapScript(values:Array<Float>):Void
  {
    heapScript = values.copy();
  }

  public static function queryHeapUsedBytes():Float
  {
    if (heapScript.length == 0) return -1;
    return heapScript.shift();
  }

  public static function reset():Void
  {
    enabled = false;
    heapScript = [];
  }
}
