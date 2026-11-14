package debug;
class FrameProfiler
{
  public static var begins:Int = 0;
  public static var ends:Int = 0;
  public static function beginGC(major:Bool):Void begins++;
  public static function endGC():Float { ends++; return 0; }
}
