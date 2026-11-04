package debug.mem;

class GetTotalMemory
{
  public static var current:Float = 805306368;   // 768 MB
  public static var peak:Float = 1073741824;      // 1 GB
  public static function getCurrentRSS():Float return current;
  public static function getPeakRSS():Float return peak;
}
