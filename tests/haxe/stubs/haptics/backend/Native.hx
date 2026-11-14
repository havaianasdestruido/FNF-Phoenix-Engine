package backend;

class Native
{
  public static inline var UNKNOWN:String = 'Unknown';

  public static function buildSystemInfo():String
    return '';

  public static function getSystemInfo():Dynamic
    return {};

  public static function getGPUName():String
    return '';

  public static function getGPUVendor():String
    return '';

  public static function getGPUDriverVersion():String
    return '';

  public static function getCPUName():String
    return '';

  public static function getCPUVendor():String
    return '';

  public static function getOSName():String
    return '';

  public static function getOSVersion():String
    return '';

  public static function getGraphicsApi():String
    return '';
}
