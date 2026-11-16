package backend;

#if (cpp && lime_cffi && !html5)
/**
 * Call Lime's native window text functions through their generic CFFI wrappers.
 * Lime's direct Prime String ABI passes hxcpp smart UTF-16 strings as raw bytes,
 * truncating non-ASCII text. The generic wrapper converts them to UTF-8 first.
 */
// Do not expose cached native function pointers through mod reflection.
@:unreflective
@:access(lime.ui.Window)
class LimeNativeText
{
  static var setTitleMethod:Dynamic = null;
  static var alertMethod:Dynamic = null;

  /** Sync Lime's getter without invoking SDL (the Android UI bridge owns the title). */
  public static function cacheTitle(window:lime.ui.Window, title:String):Void
  {
    if (window != null) window.__title = title;
  }

  public static function setTitle(window:lime.ui.Window, title:String):Bool
  {
    if (window == null || window.__backend == null || window.__backend.handle == null) return false;
    if (setTitleMethod == null)
      setTitleMethod = lime.system.CFFI.load('lime', 'lime_window_set_title', 2);
    var result:String = setTitleMethod(window.__backend.handle, title);
    if (result == null) return false;
    // Keep Lime's public getter in sync, just as Window.set_title does.
    window.__title = result;
    return result == title;
  }

  public static function alert(window:lime.ui.Window, message:String, title:String):Bool
  {
    if (window == null || window.__backend == null || window.__backend.handle == null) return false;
    if (alertMethod == null)
      alertMethod = lime.system.CFFI.load('lime', 'lime_window_alert', 3);
    alertMethod(window.__backend.handle, message, title);
    return true; // Lime's native alert has no result indicating display success.
  }
}
#end
