package utils;

/*
    VS DAVE WINDOWS/LINUX/MACOS UTIL
    You can use this code while you give credit to it.
    65% of the code written by chromasen
    35% of the code written by Erizur (cross-platform and extra windows utils)

    Windows: You need the Windows SDK (any version) to compile.
    Linux: TODO
    macOS: TODO

    credits to the vs dave team right here uh yeah i love ya guys
*/
class PlatformUtil
{
	#if cpp
	/**
	 * Executes the `getWindowsTransparent` operation.
	 * @param res Input value for `res`.
	 * @return Result produced by `getWindowsTransparent`, when applicable.
	 */
	static public function getWindowsTransparent(res:Int = 0)   // Only works on windows, otherwise returns 0!
	{
		return PlatformUtilNative.getWindowsTransparentNative(res);
	}

    /**
     * Executes the `sendFakeMsgBox` operation.
     * @param desc Input value for `desc`.
     * @param res Input value for `res`.
     * @return Result produced by `sendFakeMsgBox`, when applicable.
     */
    static public function sendFakeMsgBox(desc:String = "", res:Int = 0)    // TODO: Linux and macOS (will do soon)
    {
        return PlatformUtilNative.sendFakeMsgBoxNative(desc, res);
    }

	/**
	 * Executes the `getWindowsBackward` operation.
	 * @param res Input value for `res`.
	 * @return Result produced by `getWindowsBackward`, when applicable.
	 */
	static public function getWindowsBackward(res:Int = 0)  // Only works on windows, otherwise returns 0!
	{
		return PlatformUtilNative.getWindowsBackwardNative(res);
	}

    /**
     * Executes the `updateWallpaper` operation.
     * @return Result produced by `updateWallpaper`, when applicable.
     */
    static public function updateWallpaper() {  // Only works on windows, otherwise returns 0!
        return PlatformUtilNative.updateWallpaperNative();
    }

	/**
	 * Executes the `detectWine` operation.
	 * @return Result produced by `detectWine`, when applicable.
	 */
	public static function detectWine():Bool {
		return PlatformUtilNative.detectWineNative();
	}
	
	/**
	 * Executes the `getArch` operation.
	 * @return Result produced by `getArch`, when applicable.
	 */
	public static function getArch():String {
		return PlatformUtilNative.getArchNative();
	}
	#end
}
