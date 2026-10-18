package backend;

/**
 * Native CPU / operating system queries.
 *
 * The real work happens in C++ (`source/backend/native/include/phoenix_hardware.h`):
 * the Windows build reads the CPU name from the registry, macOS asks `sysctl`
 * and Linux/Android parses `/proc/cpuinfo`.
 *
 * Every query returns an empty string when the platform cannot answer it, so
 * the callers can fall back to "Unknown" instead of handling errors.
 */
#if cpp
@:buildXml('<include name="../../../../source/backend/native/build.xml" />')
@:include("phoenix_hardware.h")
@:keep
class NativeHardware
{
  /**
   * The CPU vendor, e.g. "GenuineIntel" or "ARM". Empty when unknown.
   */
  @:functionCode('
    char buffer[256];
    buffer[0] = 0;
    phoenixCpuVendor(buffer, sizeof(buffer));
    return ::String(buffer);
  ')
  public static function cpuVendor():String
  {
    return "";
  }

  /**
   * The CPU model, e.g. "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz".
   * Empty when unknown.
   */
  @:functionCode('
    char buffer[256];
    buffer[0] = 0;
    phoenixCpuModel(buffer, sizeof(buffer));
    return ::String(buffer);
  ')
  public static function cpuModel():String
  {
    return "";
  }

  /**
   * The operating system name, e.g. "Windows". Empty when unknown.
   */
  @:functionCode('
    char buffer[256];
    buffer[0] = 0;
    phoenixOsName(buffer, sizeof(buffer));
    return ::String(buffer);
  ')
  public static function osName():String
  {
    return "";
  }

  /**
   * The operating system version, e.g. "10.0.19045". Empty when unknown.
   */
  @:functionCode('
    char buffer[256];
    buffer[0] = 0;
    phoenixOsVersion(buffer, sizeof(buffer));
    return ::String(buffer);
  ')
  public static function osVersion():String
  {
    return "";
  }
}
#else
/**
 * Native CPU / operating system queries.
 *
 * Not available on this target: every query returns an empty string, which the
 * engine reports as "Unknown".
 */
class NativeHardware
{
  /** The CPU vendor. Empty on this target. */
  public static function cpuVendor():String
    return "";

  /** The CPU model. Empty on this target. */
  public static function cpuModel():String
    return "";

  /** The operating system name. Empty on this target. */
  public static function osName():String
    return "";

  /** The operating system version. Empty on this target. */
  public static function osVersion():String
    return "";
}
#end
