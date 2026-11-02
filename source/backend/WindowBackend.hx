package backend;

/** Legacy entry points retained for mods; all native work is shared with Windows. */
class WindowBackend
{
  public static function setWindowColorMode(isDarkMode:Bool):Bool
    return Windows.setDarkMode(isDarkMode);
}
