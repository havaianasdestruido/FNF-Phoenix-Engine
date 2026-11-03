package system;

/** Compatibility facade for native frame settings, independent of Lime's Window. */
class Window
{
  /** Set the native frame color mode. Returns false when DWM rejects the request. */
  public static function setDarkMode(enabled:Bool = true):Bool
    return Windows.setDarkMode(enabled);

  /** Compatibility entry point: set DWM mode, then refresh the native frame. */
  public static function darkMode(enabled:Bool = true):Bool
  {
    final applied = setDarkMode(enabled);
    if (applied) redrawFrame();
    return applied;
  }

  /**
   * Toggle Lime's borderless property and restore its original value. This is
   * a frame refresh, not a persistent border setting. Never toggle fullscreen.
   */
  public static function redrawFrame():Bool
  {
    #if !flash
    final app = lime.app.Application.current;
    final window = app != null ? app.window : null;
    if (window == null || window.fullscreen) return false;
    final original = window.borderless;
    var restored = false;
    try
    {
      window.borderless = !original;
      window.borderless = original;
      restored = window.borderless == original;
    }
    catch (error:Dynamic)
    {
      try
      {
        window.borderless = original;
      }
      catch (restoreError:Dynamic)
      {
        trace('Unable to restore window border: $restoreError');
      }
      trace('Unable to refresh window frame: $error');
    }
    return restored;
    #else
    return false;
    #end
  }
}
