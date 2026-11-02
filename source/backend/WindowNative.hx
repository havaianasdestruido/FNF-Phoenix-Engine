package backend;

/** Internal hxcpp bridge. Public callers use Windows or TransparentWindow. */
#if (cpp && windows)
@:buildXml('<include name="../../../../source/backend/native/window_build.xml" />')
@:cppFileCode('#include "phoenix_window.h"')
class WindowNative
{
  @:functionCode('return phoenixWindowSelect(title.c_str());')
  public static function select(title:String):Bool
    return false;

  @:functionCode('return phoenixWindowSetDarkMode(enabled);')
  public static function setDarkMode(enabled:Bool):Bool
    return false;

  @:functionCode('return phoenixWindowSetFrameColor((DWORD)attribute, (COLORREF)color);')
  public static function setFrameColor(attribute:Int, color:Int):Bool
    return false;

  @:functionCode('return phoenixWindowSetCloseEnabled(enabled);')
  public static function setCloseEnabled(enabled:Bool):Bool
    return false;

  @:functionCode('return phoenixWindowSetBlur(enabled);')
  public static function setBlur(enabled:Bool):Bool
    return false;

  @:functionCode('return phoenixWindowSetSquareCorners(square);')
  public static function setSquareCorners(square:Bool):Bool
    return false;

  @:functionCode('return phoenixWindowSetOpacity(opacity);')
  public static function setOpacity(opacity:Float):Bool
    return false;

  @:functionCode('return phoenixWindowSetColorKey((COLORREF)color, enabled);')
  public static function setColorKey(color:Int, enabled:Bool):Bool
    return false;

  @:functionCode('return phoenixWindowSetClickThrough(enabled);')
  public static function setClickThrough(enabled:Bool):Bool
    return false;

  @:functionCode('return phoenixWindowResetTransparency();')
  public static function resetTransparency():Bool
    return false;
}
#else
/** Unsupported targets compile to safe no-ops with the same signatures. */
class WindowNative
{
  public static function select(title:String):Bool
    return false;

  public static function setDarkMode(enabled:Bool):Bool
    return false;

  public static function setFrameColor(attribute:Int, color:Int):Bool
    return false;

  public static function setCloseEnabled(enabled:Bool):Bool
    return false;

  public static function setBlur(enabled:Bool):Bool
    return false;

  public static function setSquareCorners(square:Bool):Bool
    return false;

  public static function setOpacity(opacity:Float):Bool
    return false;

  public static function setColorKey(color:Int, enabled:Bool):Bool
    return false;

  public static function setClickThrough(enabled:Bool):Bool
    return false;

  public static function resetTransparency():Bool
    return false;
}
#end
