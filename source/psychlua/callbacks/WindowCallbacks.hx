package psychlua.callbacks;

import backend.TransparentWindow;
import psychlua.FunkinLua;

/**
 * Window-level helpers exposed to Lua scripts (desktop overlay / "desktop pet"
 * mods): transparency, whole-window alpha and click-through.
 *
 * All of them are thin wrappers around `backend.TransparentWindow` and are safe
 * no-ops that log a reason on targets without support (HTML5, Flash/AIR,
 * mobile), so a mod can call them unconditionally.
 *
 * The Python mirror lives in `psychlua.pystdlib.PyWindowLib`; keep the function
 * names and argument order in sync.
 */
class WindowCallbacks
{
  public static function register(funk:FunkinLua):Void
  {
    @:privateAccess {
      // Makes the window see-through: every pixel painted with the transparency
      // color (RGB 1,1,1 by default) disappears and shows the desktop behind it.
      // Windows only; leaves fullscreen when the game is in it.
      FunkinLua.registerFunction("setWindowTransparent", function(enable:Bool = true) {
        return TransparentWindow.setEnabled(enable);
      });
      // Reads back whether transparency is on (it may be suspended by fullscreen).
      FunkinLua.registerFunction("getWindowTransparent", function() {
        return TransparentWindow.enabled;
      });
      // Whole-window opacity: 0 = invisible, 1 = opaque. Windows, Linux and macOS.
      FunkinLua.registerFunction("setWindowAlpha", function(alpha:Float) {
        return TransparentWindow.setAlpha(alpha);
      });
      // The last opacity set through setWindowAlpha.
      FunkinLua.registerFunction("getWindowAlpha", function() {
        return TransparentWindow.alpha;
      });
      // The color that renders see-through. Takes a number (0xFF010101) or a
      // string ('010101', '#010101', '0xFF010101'). Windows only.
      FunkinLua.registerFunction("setWindowTransparencyColor", function(color:Dynamic) {
        return TransparentWindow.setColorKey(TransparentWindow.parseColor(color));
      });
      // Lets clicks pass through the window. Windows only.
      FunkinLua.registerFunction("setWindowClickThrough", function(enable:Bool = true) {
        return TransparentWindow.setClickThrough(enable);
      });
      // Whether the window is currently ignoring the mouse.
      FunkinLua.registerFunction("isWindowClickThrough", function() {
        return TransparentWindow.clickThrough;
      });
      // False on HTML5/Flash/mobile: every setter above is a no-op there.
      FunkinLua.registerFunction("isWindowTransparencySupported", function() {
        return TransparentWindow.isSupported;
      });
      // Re-applies the stored settings, e.g. after the window was recreated.
      FunkinLua.registerFunction("applyWindowTransparency", function() {
        return TransparentWindow.apply();
      });
    }
  }
}
