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

  @:functionCode('return phoenixWindowIsLightTheme();')
  public static function isLightTheme():Bool
    return true;

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

  @:functionCode('return phoenixWindowMessageBox(message.c_str(), title.c_str(), yesNo, error);')
  public static function messageBox(message:String, title:String, yesNo:Bool, error:Bool):Int
    return 0;

  @:functionCode('return phoenixWindowNotify(title.c_str(), message.c_str());')
  public static function notify(title:String, message:String):Bool
    return false;

  @:functionCode('return phoenixWindowRemoveNotification();')
  public static function removeNotification():Bool
    return false;

  @:functionCode('
    char appData[MAX_PATH] = {0};
    const DWORD length = GetEnvironmentVariableA("APPDATA", appData, MAX_PATH);
    if (length == 0 || length >= MAX_PATH)
      return false;
    std::string path(appData);
    path.append("\\Microsoft\\Windows\\Themes\\TranscodedWallpaper");
    return SystemParametersInfoA(SPI_SETDESKWALLPAPER, 0, (PVOID)path.c_str(), SPIF_UPDATEINIFILE) != 0;
  ')
  public static function updateWallpaper():Bool
    return false;

  @:functionCode('
    HMODULE ntdll = GetModuleHandleA("ntdll.dll");
    if (ntdll != NULL && GetProcAddress(ntdll, "wine_get_version") != NULL)
      return true;
    return false;
  ')
  public static function detectWine():Bool
    return false;

  @:functionCode('
    SYSTEM_INFO info;
    GetSystemInfo(&info);
    switch (info.wProcessorArchitecture)
    {
      case 9: return ::String("x86_64");
      case 5: return ::String("ARM");
      case 12: return ::String("ARM64");
      case 6: return ::String("IA-64");
      case 0: return ::String("x86");
      default: return ::String("Unknown");
    }
  ')
  public static function getArch():String
    return null;

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

  public static function isLightTheme():Bool
    return true;

  public static function setFrameColor(attribute:Int, color:Int):Bool
    return false;

  public static function setCloseEnabled(enabled:Bool):Bool
    return false;

  public static function setBlur(enabled:Bool):Bool
    return false;

  public static function setSquareCorners(square:Bool):Bool
    return false;

  public static function messageBox(message:String, title:String, yesNo:Bool, error:Bool):Int
    return 0;

  public static function notify(title:String, message:String):Bool
    return false;

  public static function removeNotification():Bool
    return false;

  public static function updateWallpaper():Bool
    return false;

  public static function detectWine():Bool
    return false;

  public static function getArch():String
    return null;

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
