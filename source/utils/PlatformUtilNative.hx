package utils;

// basically PlatformUtil but where all the code glue goes
#if cpp
@:buildXml('<include name="../../../../source/utils/build.xml" />')
@:include("phoenix_desktop_dialog.h")
#if windows
// Windows native calls live in backend.WindowNative; keep this class free of
// Windows SDK includes so hxcpp's include order cannot break the build.
@:cppFileCode('/* Windows dialogs are provided by backend.WindowNative. */')
#elseif linux
@:cppFileCode('
#include <stdlib.h>
#include <stdio.h>
#include <iostream>
#include <string>
#include <sys/utsname.h>
')
#elseif (ios || mac)
@:cppFileCode('
#include <mach-o/arch.h>
#include <sys/utsname.h>
')
#elseif android
@:cppFileCode('
#include <sys/utsname.h>
')
#end
#end
@:allow(utils.PlatformUtil)
class PlatformUtilNative
{
  #if linux
  /*
    REQUIRES IMPORTING X11 LIBRARIES (Xlib, Xutil, Xatom) to run, even tho it doesnt work
    @:functionCode('
        Display* display = XOpenDisplay(NULL);
        Window wnd;
        Atom property = XInternAtom(display, "_NET_WM_WINDOW_OPACITY", False);
        int revert;

        if(property != None)
        {
            XGetInputFocus(display, &wnd, &revert);
            unsigned long opacity = (0xff000000 / 0xffffffff) * 50;
            XChangeProperty(display, wnd, property, XA_CARDINAL, 32, PropModeReplace, (unsigned char*)&opacity, 1);
            XFlush(display);
        }
        XCloseDisplay(display);
    ')
   */
  #end
  static function getWindowsTransparentNative(res:Int = 0) // Only works on windows, otherwise returns 0!
  {
    #if windows
    return backend.FlxTransWindow.getWindowsTransparent(res);
    #else
    return res;
    #end
  }

  #if linux
  @:functionCode('
        res = phoenixShowLinuxDesktopDialog(std::string(desc.c_str()));
    ')
  #elseif mac
  @:functionCode('
        res = phoenixShowMacDesktopDialog(std::string(desc.c_str()));
    ')
  #end
  static function sendFakeMsgBoxNative(desc:String = "", res:Int = 0)
  {
    #if windows
    @:functionCode('\n        LPCSTR lwDesc = desc.c_str();\n\n        res = MessageBox(\n            NULL,\n            lwDesc,\n            NULL,\n            MB_OK\n        );\n    ')
    #elseif linux
    @:functionCode('\n        res = phoenixShowLinuxDesktopDialog(std::string(desc.c_str()));\n    ')
    #elseif mac
    @:functionCode('\n        res = phoenixShowMacDesktopDialog(std::string(desc.c_str()));\n    ')
    #end
    return res;
    #end
  }

  static function getWindowsBackwardNative(res:Int = 0) // Only works on windows, otherwise returns 0!
  {
    #if windows
    return backend.FlxTransWindow.getWindowsbackward(res);
    #else
    return res;
    #end
  }

  static function updateWallpaperNative()
  { // Only works on windows, otherwise returns 0!
    #if windows
    return backend.WindowNative.updateWallpaper();
    #else
    return null;
    #end
  }

  static function detectWineNative():Bool
  {
    #if windows
    return backend.WindowNative.detectWine();
    #else
    return false;
    #end
  }

  #if (ios || mac)
  @:functionCode('
			const NXArchInfo *archInfo = NXGetLocalArchInfo();
    	return ::String(archInfo == NULL ? "Unknown" : archInfo->name);
	')
  #elseif !windows
  @:functionCode('
			struct utsname osInfo{};
			uname(&osInfo);
			return ::String(osInfo.machine);
	')
  #end
  @:noCompletion
  static function getArchNative():String
  {
    #if windows
    return backend.WindowNative.getArch();
    #else
    return null;
    #end
  }
}
