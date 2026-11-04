package utils;

    /*
    VS DAVE WINDOWS/LINUX/MACOS UTIL
    You can use this code while you give credit to it.
    65% of the code written by chromasen
    35% of the code written by Erizur (cross-platform and extra windows utils)

    Windows: You need the Windows SDK (any version) to compile.
    Linux: Native zenity/kdialog implementation via phoenixShowLinuxDesktopDialog
    macOS: Native osascript implementation via phoenixShowMacDesktopDialog

    credits to the vs dave team right here uh yeah i love ya guys
*/
class PlatformUtil
{
	#if cpp
	static public function getWindowsTransparent(res:Int = 0)   // Only works on windows, otherwise returns 0!
	{
		return PlatformUtilNative.getWindowsTransparentNative(res);
	}

    /** Windows whole-window opacity (0.0–1.0); false on unsupported targets. */
    public static function setWindowOpacity(opacity:Float):Bool
    {
        return Windows.__setWindowTransparencyAlpha(opacity);
    }

    /** Show a Windows notification-area message; false on unsupported targets. */
    public static function sendNotification(title:String, message:String):Bool
    {
        return Windows.sendWindowsNotification(title, message);
    }

    /** Shows the native crash dialog available on the current desktop platform. */
    static public function sendFakeMsgBox(desc:String = "", res:Int = 0)
    {
        return PlatformUtilNative.sendFakeMsgBoxNative(desc, res);
    }

	static public function getWindowsBackward(res:Int = 0)  // Only works on windows, otherwise returns 0!
	{
		return PlatformUtilNative.getWindowsBackwardNative(res);
	}

    static public function updateWallpaper() {  // Only works on windows, otherwise returns 0!
        return PlatformUtilNative.updateWallpaperNative();
    }

	public static function detectWine():Bool {
		return PlatformUtilNative.detectWineNative();
	}


	public static function getArch():String {
		return PlatformUtilNative.getArchNative();
	}
	#end

    #if !cpp
    /** Non-native targets cannot show shell notifications. */
    public static function sendNotification(title:String, message:String):Bool return false;
    #end

    /**
     * Trace helper for 4th-wall-breaking (`META_HORROR`) effects called on a
     * build without the define or on a platform where the effect does not exist.
     * Compiled on every target so `backend.MetaHorror` no-op paths typecheck everywhere.
     */
    public static function unsupportedMetaHorror(fn:String):Void {
        trace('MetaHorror.$fn requires a -DMETA_HORROR build and is not supported on this platform.');
    }
}
