package;

import backend.WindowNative;

/**
 * Native Windows desktop integration. Every setter returns whether the OS
 * accepted the request; other targets are safe no-ops returning false.
 * Use backend.TransparentWindow for fullscreen-aware mod transparency.
 */
class Windows
{
  public static var isSupported(get, never):Bool;

  static inline function get_isSupported():Bool
  {
    #if (cpp && windows)
      return true;
    #else
      return false;
    #end
  }

  /** Resolve the current Lime window by title and owning process before an operation. */
  public static function prepare():Bool
  {
    #if (cpp && windows)
      final app = lime.app.Application.current;
      final window = app != null ? app.window : null;
      return window != null && WindowNative.select(window.title != null ? window.title : "");
    #else
      return false;
    #end
  }

  /** Request a dark (or light) native frame; does not recolor game graphics. */
  public static function setDarkMode(enabled:Bool = true):Bool
    return prepare() && WindowNative.setDarkMode(enabled);

  /** Validate an RGB triplet and convert it to Win32's COLORREF byte order. */
  static function colorRef(color:Array<Int>):Int
  {
    if (color == null || color.length < 3)
      return -1;
    for (channel in color.slice(0, 3))
      if (channel < 0 || channel > 255) return -1;
    return color[0] | (color[1] << 8) | (color[2] << 16);
  }

  /** Set the Windows 11 caption and/or border color. RGB channels are 0–255. */
  public static function setWindowBorderColor(color:Array<Int>, setHeader:Bool = true, setBorder:Bool = true):Bool
  {
    final value = colorRef(color);
    if (value < 0 || !prepare()) return false;
    var result = true;
    if (setHeader && !WindowNative.setFrameColor(35, value)) result = false;
    if (setBorder && !WindowNative.setFrameColor(34, value)) result = false;
    return result && (setHeader || setBorder);
  }

  /** Set the Windows 11 title text color. RGB channels are 0–255. */
  public static function setWindowTitleColor(color:Array<Int>):Bool
  {
    final value = colorRef(color);
    return value >= 0 && prepare() && WindowNative.setFrameColor(36, value);
  }

  /** Restore the system default border, caption, and title text colors. */
  public static function resetWindowFrameColors():Bool
  {
    if (!prepare()) return false;
    var result = true;
    for (attribute in [34, 35, 36])
      if (!WindowNative.setFrameColor(attribute, -1)) result = false;
    return result;
  }

  /**
   * Enable/disable the native Close command (also gates Alt+F4). This is not a
   * security boundary; always restore it when a temporary effect finishes.
   */
  public static function setCloseButtonEnabled(enabled:Bool):Bool
    return prepare() && WindowNative.setCloseEnabled(enabled);

  /**
   * Request legacy DWM blur behind the window. Modern Windows may accept the
   * request without drawing blur; false means the API rejected it.
   */
  public static function setWindowBlur(enabled:Bool = true):Bool
    return prepare() && WindowNative.setBlur(enabled);

  /** Compatibility name for setWindowBlur(). */
  public static function test(enabled:Bool = true):Bool
    return setWindowBlur(enabled);

  /** Set whole-window opacity, from 0.0 (invisible) to 1.0 (opaque). */
  public static function __setWindowTransparencyAlpha(alpha:Float):Bool
    return prepare() && WindowNative.setOpacity(alpha);

  /** Set or disable an RGB color key (0xRRGGBB); alpha bytes are ignored. */
  public static function __setWindowTransparencyColor(color:Int, enabled:Bool = true):Bool
  {
    // Haxe/Flixel colors are 0xRRGGBB; Win32 COLORREF is 0x00BBGGRR.
    final colorRef = ((color & 0xFF) << 16) | (color & 0xFF00) | ((color >> 16) & 0xFF);
    return prepare() && WindowNative.setColorKey(colorRef, enabled);
  }

  /** Make mouse input pass through the game window. */
  public static function setWindowClickThrough(enabled:Bool):Bool
    return prepare() && WindowNative.setClickThrough(enabled);

  /** Remove only Phoenix's layered/click-through effects, preserving other styles. */
  public static function resetWindowTransparency():Bool
    return prepare() && WindowNative.resetTransparency();
}
