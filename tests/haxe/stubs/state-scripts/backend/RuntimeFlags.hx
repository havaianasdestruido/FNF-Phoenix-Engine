package backend;

/** Settable stand-in for the runtime-flag store. */
class RuntimeFlags
{
  public static var strings:Map<String, String> = new Map();

  public static function reset():Void
  {
    strings = new Map();
  }

  public static function getString(key:String, fallback:String = ''):String
    return strings.exists(key) ? strings.get(key) : fallback;
}
