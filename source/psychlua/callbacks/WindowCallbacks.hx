package psychlua.callbacks;

import backend.TransparentWindow;
import backend.WindowMode;
import flixel.FlxG;
import psychlua.FunkinLua;

/**
 * Window-level helpers exposed to Lua scripts (desktop overlay / "desktop pet"
 * mods): transparency, whole-window alpha, click-through, the window display
 * mode and window size.
 *
 * All of them are thin wrappers around `backend.TransparentWindow` /
 * `backend.WindowMode` and are safe no-ops that log a reason on targets without
 * support (HTML5, Flash/AIR, mobile), so a mod can call them unconditionally.
 *
 * The Python mirror lives in `psychlua.pystdlib.PyWindowLib`; HScript seeds the
 * same surface from `seedHScript()`. Keep the function names and argument order
 * in sync across all three.
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

      registerModeApi(function(name:String, func:Dynamic) {
        FunkinLua.registerFunction(name, func);
      });
    }
  }

  /**
   * Seed the same window-mode / size API into an HScript interpreter's scope.
   *
   * HScript inherits the shared Lua registry when a Lua script is loaded, but a
   * mod that ships only `.hx` scripts has no Lua parent, so this seeds the API
   * directly (mirroring how `MetaHorror` is seeded in `HScript.seedScope`).
   */
  public static function seedHScript(interp:Dynamic):Void
  {
    registerModeApi(function(name:String, func:Dynamic) {
      interp.variables.set(name, func);
    });
  }

  /** Window display mode and size helpers shared by every script language. */
  private static function registerModeApi(register:(String, Dynamic)->Void):Void
  {
    // Selects the window display mode: 'windowed' / 'borderless' / 'fullscreen'
    // (the display names 'Windowed', 'Borderless', 'Fullscreen' work too).
    // Applies immediately and persists the choice. Desktop only.
    register("setWindowMode", function(mode:Dynamic) {
      return WindowMode.set(mode);
    });
    // The current mode as 'Windowed' / 'Borderless' / 'Fullscreen'.
    register("getWindowMode", function():String {
      return WindowMode.current();
    });
    // Convenience for the common windowed <-> fullscreen toggle.
    register("setWindowFullscreen", function(enable:Bool = true) {
      return WindowMode.set(enable ? WindowMode.FULLSCREEN : WindowMode.WINDOWED);
    });
    // Whether the selected mode is exclusive fullscreen.
    register("getWindowFullscreen", function():Bool {
      return WindowMode.isFullscreen();
    });
    // Selects a borderless window (frameless, not exclusive fullscreen).
    register("setWindowBorderless", function(enable:Bool = true) {
      return WindowMode.set(enable ? WindowMode.BORDERLESS : WindowMode.WINDOWED);
    });
    // Whether the selected mode is borderless.
    register("getWindowBorderless", function():Bool {
      return WindowMode.isBorderless();
    });
    // Resizes the game window and the logical viewport. Desktop native only.
    register("resizeWindow", function(width:Int, height:Int) {
      return WindowMode.resize(width, height);
    });
    // Current logical game size as [width, height].
    register("getWindowSize", function() {
      return [FlxG.width, FlxG.height];
    });
  }
}
