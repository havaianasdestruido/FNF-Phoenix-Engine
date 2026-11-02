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
