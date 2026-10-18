package psychlua.pystdlib;

import backend.TransparentWindow;
import psychlua.PythonScript;

/**
 * Window-level helpers exposed to Python scripts (desktop overlay / "desktop
 * pet" mods): transparency, whole-window alpha and click-through.
 *
 * Mirror of `psychlua.callbacks.WindowCallbacks` — keep the function names and
 * the argument order in sync. All of them are thin wrappers around
 * `backend.TransparentWindow` and are safe no-ops that log a reason on targets
 * without support (HTML5, Flash/AIR, mobile).
 */
class PyWindowLib
{
  public static function register(py:PythonScript):Void
  {
    @:privateAccess {
      // Makes the window see-through: every pixel painted with the transparency
      // color (RGB 1,1,1 by default) disappears and shows the desktop behind it.
      // Windows only; leaves fullscreen when the game is in it.
      PythonScript.registerFunction("setWindowTransparent", function(enable:Bool = true) {
        return TransparentWindow.setEnabled(enable);
      });
      // Reads back whether transparency is on (it may be suspended by fullscreen).
      PythonScript.registerFunction("getWindowTransparent", function() {
        return TransparentWindow.enabled;
      });
      // Whole-window opacity: 0 = invisible, 1 = opaque. Windows, Linux and macOS.
      PythonScript.registerFunction("setWindowAlpha", function(alpha:Float) {
        return TransparentWindow.setAlpha(alpha);
      });
      // The last opacity set through setWindowAlpha.
      PythonScript.registerFunction("getWindowAlpha", function() {
        return TransparentWindow.alpha;
      });
      // The color that renders see-through. Takes a number (0xFF010101) or a
      // string ('010101', '#010101', '0xFF010101'). Windows only.
      PythonScript.registerFunction("setWindowTransparencyColor", function(color:Dynamic) {
        return TransparentWindow.setColorKey(TransparentWindow.parseColor(color));
      });
      // Lets clicks pass through the window. Windows only.
      PythonScript.registerFunction("setWindowClickThrough", function(enable:Bool = true) {
        return TransparentWindow.setClickThrough(enable);
      });
      // Whether the window is currently ignoring the mouse.
      PythonScript.registerFunction("isWindowClickThrough", function() {
        return TransparentWindow.clickThrough;
      });
      // False on HTML5/Flash/mobile: every setter above is a no-op there.
      PythonScript.registerFunction("isWindowTransparencySupported", function() {
        return TransparentWindow.isSupported;
      });
      // Re-applies the stored settings, e.g. after the window was recreated.
      PythonScript.registerFunction("applyWindowTransparency", function() {
        return TransparentWindow.apply();
      });
    }
  }
}
