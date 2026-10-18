package backend;

import StringTools;
import flixel.FlxG;
import flixel.util.FlxColor;

/**
 * Transparent window support — the "4th wall breaking" desktop-pet / overlay
 * feature (issue #95).
 *
 * Two independent effects are exposed:
 *
 * 1. **Color-key transparency** (`setEnabled`, Windows only): every pixel
 *    painted with `colorKey` (`RGB(1, 1, 1)` by default) is punched out of the
 *    window, so the desktop shows through. Paint the game background with that
 *    color first — e.g. `FlxG.camera.bgColor = 0xFF010101` or, from a script,
 *    `setProperty('camGame.bgColor', '010101')`.
 * 2. **Whole-window alpha** (`setAlpha`, Windows/Linux/macOS): `0.0` is
 *    invisible, `1.0` is opaque. Off Windows this goes through Lime/SDL
 *    (`window.opacity`) and is the only part that works there.
 *
 * Click-through (`setClickThrough`, Windows only) makes the window ignore the
 * mouse, which is what an overlay/pet mod usually wants.
 *
 * Everything is a **safe no-op with a logged reason** on targets that cannot do
 * it (HTML5, Flash/AIR, Android, iOS): the setters return `false`, they never
 * throw, and they never change the stored state in a way that could surprise a
 * later `enable()`.
 *
 * Fullscreen is handled for you: transparency only makes sense on a windowed
 * game, so enabling it leaves fullscreen, and entering fullscreen (F11,
 * `FlxG.fullscreen`, …) suspends the effect until the game is windowed again.
 *
 * Haxe:
 * ```haxe
 * TransparentWindow.setColorKey(0xFF010101);
 * TransparentWindow.setAlpha(0.85);
 * TransparentWindow.setEnabled(true);
 * TransparentWindow.setClickThrough(true);
 * ```
 *
 * Scripts (Lua and Python) use `setWindowTransparent`, `setWindowAlpha`,
 * `setWindowTransparencyColor` and `setWindowClickThrough`.
 *
 * @see backend.FlxTransWindow — the native backend, ported from psych-engine-modified-build.
 */
class TransparentWindow
{
  /**
   * The color the ported `FlxTransWindow` used: `RGB(1, 1, 1)`. Near-black but
   * not pure black, so artwork that is actually black stays visible.
   */
  public static var DEFAULT_COLOR_KEY:FlxColor = 0xFF010101;

  /**
   * Whether the color-key transparency is on. It may be temporarily suspended
   * by fullscreen; check `isActive` to know if the window is really see-through
   * right now.
   */
  public static var enabled(default, null):Bool = false;

  /**
   * Whole-window opacity: `0.0` (invisible) to `1.0` (opaque). Applied as soon
   * as it is set (where supported) and re-applied by `setEnabled(true)`.
   */
  public static var alpha(default, null):Float = 1;

  /** The color rendered as fully see-through while transparency is enabled. */
  public static var colorKey(default, null):FlxColor = DEFAULT_COLOR_KEY;

  /** Whether the window ignores the mouse (Windows only). */
  public static var clickThrough(default, null):Bool = false;

  /** Set while the game is fullscreen, when the effect cannot be shown. */
  static var suspended:Bool = false;

  static var initialized:Bool = false;

  /** Remembers which "unsupported" messages were already printed. */
  static var reported:Map<String, Bool> = [];

  /* ---------------------------------------------------------------------- */
  /*                            SUPPORT QUERIES                             */
  /* ---------------------------------------------------------------------- */

  /** `true` when at least one of the two effects works on this target. */
  public static var isSupported(get, never):Bool;

  static inline function get_isSupported():Bool
    return supportsColorKey || supportsAlpha;

  /** `true` when the color-key (really see-through) effect works here. */
  public static var supportsColorKey(get, never):Bool;

  static inline function get_supportsColorKey():Bool
  {
    #if (cpp && windows)
      return true;
    #else
      return false;
    #end
  }

  /** `true` when the whole-window alpha works here. */
  public static var supportsAlpha(get, never):Bool;

  static inline function get_supportsAlpha():Bool
  {
    #if (cpp && (windows || linux || mac))
      return true;
    #else
      return false;
    #end
  }

  /** `true` when `setClickThrough()` works here. */
  public static var supportsClickThrough(get, never):Bool;

  static inline function get_supportsClickThrough():Bool
  {
    #if (cpp && windows)
      return true;
    #else
      return false;
    #end
  }

  /** `true` when the effect is really applied to the window right now. */
  public static var isActive(get, never):Bool;

  static inline function get_isActive():Bool
    return enabled && !suspended;

  /* ---------------------------------------------------------------------- */
  /*                                 SETUP                                  */
  /* ---------------------------------------------------------------------- */

  /**
   * Installs the fullscreen watcher. Called once by `Main.setupGame()`; the
   * per-frame check costs nothing until transparency is enabled.
   */
  public static function init():Void
  {
    if (initialized) return;
    initialized = true;
    FlxG.signals.preUpdate.add(syncFullscreenState);
  }

  /* ---------------------------------------------------------------------- */
  /*                              PUBLIC API                                */
  /* ---------------------------------------------------------------------- */

  /**
   * Turns the color-key transparency on or off (Windows only).
   *
   * Enabling it while the game is fullscreen leaves fullscreen first: a
   * fullscreen window covers the desktop, so there is nothing to see through.
   *
   * @param   value   `true` to make `colorKey` pixels see-through.
   * @return  `true` when the requested state was applied.
   */
  public static function setEnabled(value:Bool):Bool
  {
    if (!value)
    {
      enabled = false;
      suspended = false;
      // Re-apply instead of a plain clear: a mod may still want the alpha it
      // set, we only drop the color key (and the layered style with it when
      // there is nothing left to show).
      if (isSupported) applyNative();
      return true;
    }

    if (!supportsColorKey)
    {
      unsupported('setEnabled(true)');
      return false;
    }

    if (isFullscreenNow())
    {
      trace('TransparentWindow: leaving fullscreen — transparency only works on a windowed game.');
      FlxG.fullscreen = false;
    }

    enabled = true;
    return apply();
  }

  /** Shortcut for `setEnabled(true)`. @return `true` when it was applied. */
  public static function enable():Bool
    return setEnabled(true);

  /** Shortcut for `setEnabled(false)`. @return `true` always. */
  public static function disable():Bool
    return setEnabled(false);

  /** Flips the transparency state. @return the new state, when it was applied. */
  public static function toggle():Bool
  {
    setEnabled(!enabled);
    return enabled;
  }

  /**
   * Sets the whole-window opacity (Windows, Linux and macOS).
   *
   * @param   value   `0.0` (invisible) to `1.0` (opaque); clamped to that range.
   * @return  `true` when it was applied.
   */
  public static function setAlpha(value:Float):Bool
  {
    if (Math.isNaN(value)) value = 1;
    alpha = Math.max(0, Math.min(1, value));

    if (!supportsAlpha)
    {
      unsupported('setAlpha');
      return false;
    }

    return apply();
  }

  /**
   * Changes the color that renders see-through (Windows only).
   *
   * Remember to paint the game background with it, otherwise nothing changes.
   *
   * @param   color   Any `FlxColor`, e.g. `0xFF010101`.
   * @return  `true` when it was applied (or stored for the next `enable()`).
   */
  public static function setColorKey(color:FlxColor):Bool
  {
    colorKey = color;

    if (!supportsColorKey)
    {
      unsupported('setColorKey');
      return false;
    }

    if (!enabled) return true; // stored; applied by the next enable/apply
    return apply();
  }

  /**
   * Makes the window ignore the mouse (Windows only) — the usual companion of
   * an overlay style mod.
   *
   * @param   value   `true` to let clicks pass through to whatever is behind.
   * @return  `true` when it was applied.
   */
  public static function setClickThrough(value:Bool):Bool
  {
    clickThrough = value;

    if (!supportsClickThrough)
    {
      unsupported('setClickThrough');
      return false;
    }

    #if (cpp && windows)
      FlxTransWindow.setClickThrough(value);
      return true;
    #else
      return false;
    #end
  }

  /**
   * Re-applies every stored setting to the window. Call it if the effect
   * vanished (monitor change, the window being recreated, …).
   *
   * @return  `true` when the effect is active on the window afterwards.
   */
  public static function apply():Bool
  {
    if (!isSupported) return false;

    if (enabled && isFullscreenNow())
    {
      if (!suspended)
      {
        suspended = true;
        trace('TransparentWindow: transparency is suspended while the game is fullscreen.');
      }
      #if (cpp && windows)
        FlxTransWindow.clearTransparentWindow();
      #end
      return false;
    }

    suspended = false;
    applyNative();
    return true;
  }

  /** Restores a normal, opaque, clickable window and forgets every setting. */
  public static function reset():Void
  {
    enabled = false;
    suspended = false;
    alpha = 1;
    colorKey = DEFAULT_COLOR_KEY;
    clickThrough = false;

    #if (cpp && windows)
      FlxTransWindow.clearTransparentWindow();
    #elseif (!flash && !mobile)
      final window = getWindow();
      if (window != null) window.opacity = 1;
    #end
  }

  /**
   * Keeps the effect in sync with the window mode: suspends it while the game
   * is fullscreen and restores it as soon as it is windowed again. Driven by
   * `FlxG.signals.preUpdate` (installed by `init()`), it returns immediately
   * when transparency is off.
   */
  public static function syncFullscreenState():Void
  {
    if (!enabled) return;

    final fullscreen:Bool = isFullscreenNow();
    if (fullscreen == suspended) return;

    if (fullscreen)
    {
      suspended = true;
      #if (cpp && windows)
        FlxTransWindow.clearTransparentWindow();
      #end
      trace('TransparentWindow: transparency suspended while fullscreen.');
    }
    else
    {
      suspended = false;
      apply();
    }
  }

  /**
   * Reads a color the way scripts hand it over: either a raw number
   * (`0xFF010101`) or a string (`'010101'`, `'#010101'`, `'0xFF010101'`,
   * `'RGB'` shorthand). Anything unparsable keeps the current color key.
   *
   * @param   value   A number or a color string.
   * @return  The parsed color, or the current `colorKey` when it cannot be read.
   */
  public static function parseColor(value:Dynamic):FlxColor
  {
    if (value == null) return colorKey;
    if (Std.isOfType(value, Int)) return (cast value : Int);
    if (Std.isOfType(value, Float)) return Std.int((cast value : Float));

    final text:String = StringTools.trim(Std.string(value));
    if (text.length > 0)
    {
      var hex:String = text;
      if (hex.indexOf("0x") == 0 || hex.indexOf("0X") == 0) hex = hex.substr(2);
      else if (hex.indexOf("#") == 0) hex = hex.substr(1);

      if (hex.length == 3) // "RGB" shorthand
        hex = hex.charAt(0) + hex.charAt(0) + hex.charAt(1) + hex.charAt(1) + hex.charAt(2) + hex.charAt(2);
      if (hex.length == 6) hex = "ff" + hex; // no alpha given, keep it opaque

      final parsed:Null<Int> = Std.parseInt("0x" + hex);
      if (parsed != null) return parsed;
    }

    return colorKey;
  }

  /* ---------------------------------------------------------------------- */
  /*                              INTERNALS                                 */
  /* ---------------------------------------------------------------------- */

  /** Pushes the current state down to the native window. */
  static function applyNative():Void
  {
    #if (cpp && windows)
      if (enabled)
        FlxTransWindow.setTransparentWindow(colorKey.red, colorKey.green, colorKey.blue, alpha);
      else if (alpha < 1)
        FlxTransWindow.setAlphaWindow(alpha);
      else
        FlxTransWindow.clearTransparentWindow();

      FlxTransWindow.setClickThrough(clickThrough);
    #elseif (!flash && !mobile)
      // No color key off Windows: Lime/SDL only gives us whole-window opacity.
      final window = getWindow();
      if (window != null) window.opacity = alpha;
    #end
  }

  /**
   * The Lime window, or `null` when the target has none (Flash).
   *
   * Typed as `Dynamic` on purpose: `lime.ui.Window` is only reachable on the
   * targets that actually have a native window.
   */
  static function getWindow():Dynamic
  {
    #if !flash
      if (FlxG.stage != null && FlxG.stage.window != null) return FlxG.stage.window;
      final app:lime.app.Application = lime.app.Application.current;
      return (app != null) ? app.window : null;
    #else
      return null;
    #end
  }

  static function isFullscreenNow():Bool
  {
    #if !flash
      final window = getWindow();
      if (window != null) return window.fullscreen == true;
    #end
    return FlxG.fullscreen;
  }

  /** Logs "not supported" once per function so mods cannot spam the log. */
  static function unsupported(functionName:String):Void
  {
    if (reported.exists(functionName)) return;
    reported.set(functionName, true);
    trace('TransparentWindow.$functionName is not available on this platform ($targetName)!');
  }

  /** Compile-time name of the current target, used by `unsupported()`. */
  static var targetName(get, never):String;

  static inline function get_targetName():String
  {
    #if windows
      return 'windows';
    #elseif linux
      return 'linux';
    #elseif mac
      return 'macOS';
    #elseif android
      return 'android';
    #elseif ios
      return 'iOS';
    #elseif flash
      return 'flash';
    #elseif web
      return 'html5';
    #else
      return 'this target';
    #end
  }
}
