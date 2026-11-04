package backend;

/** Legacy entry points retained for mods; all native work is shared with Windows. */
class WindowBackend
{
  public static function setWindowColorMode(isDarkMode:Bool):Bool
    return Windows.setDarkMode(isDarkMode);

  public static function setWindowBorderColor(color:Array<Int>, setHeader:Bool = true, setBorder:Bool = false):Bool
    return Windows.setWindowBorderColor(color, setHeader, setBorder);

  public static function setWindowTitleColor(color:Array<Int>):Bool
    return Windows.setWindowTitleColor(color);

  public static function updateWindow():Void
  {
    system.Window.redrawFrame();
  }
}
