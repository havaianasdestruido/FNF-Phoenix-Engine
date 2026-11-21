package backend;

/** No-op stand-in for the native window mode controller. */
class WindowMode
{
  public static final WINDOWED:String = 'Windowed';
  public static final BORDERLESS:String = 'Borderless';
  public static final FULLSCREEN:String = 'Fullscreen';

  public static var currentMode:String = WINDOWED;
  public static var applyCount:Int = 0;

  public static function current():String
    return currentMode;

  public static function apply(mode:String):Void
  {
    currentMode = mode;
    applyCount++;
  }
}
