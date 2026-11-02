package system;

/** Compatibility facade for native frame settings, independent of Lime's Window. */
class Window
{
  /** Set the native frame color mode. Returns false when DWM rejects the request. */
  public static function setDarkMode(enabled:Bool = true):Bool
    return Windows.setDarkMode(enabled);
}
