package debug.system;

/** Fixed hardware answers; the report only formats whatever these return. */
class SystemInfo
{
  public static var cores:Int = 8;
  public static var ramBytes:Float = 17179869184;

  public static function logicalCPUCount():Int
    return cores;

  public static function totalPhysicalMemory():Float
    return ramBytes;
}
