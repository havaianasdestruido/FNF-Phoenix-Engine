package utils;

/*
    This is some cool system shit!
	lordRyan wrote this :D
    Shoutout to him :D
*/

#if sys
class CoolSystemStuff
{
	/**
	 * Executes the `getUsername` operation.
	 * @return Result produced by `getUsername`, when applicable.
	 */
	public static function getUsername():String
	{
		// uhh this one is self explanatory
		#if windows
		return Sys.getEnv("USERNAME");
		#else
		return Sys.getEnv("USER");
		#end
	}

	/**
	 * Executes the `getUserPath` operation.
	 * @return Result produced by `getUserPath`, when applicable.
	 */
	public static function getUserPath():String
	{
		// this one is also self explantory
		#if windows
		return Sys.getEnv("USERPROFILE");
		#else
		return Sys.getEnv("HOME");
		#end
	}

	/**
	 * Executes the `getTempPath` operation.
	 * @return Result produced by `getTempPath`, when applicable.
	 */
	public static function getTempPath():String
	{
		// gets appdata temp folder lol
		#if windows
		return Sys.getEnv("TEMP");
		#else
		// most non-windows os dont have a temp path, or if they do its not 100% compatible, so the user folder will be a fallback
		return Sys.getEnv("HOME");
		#end
	}
	/**
	 * Executes the `executableFileName` operation.
	 * @return Result produced by `executableFileName`, when applicable.
	 */
	public static function executableFileName()
	{
		#if windows
		var programPath = Sys.programPath().split("\\");
		#else
		var programPath = Sys.programPath().split("/");
		#end
		return programPath[programPath.length - 1];
	}
}
#else
class CoolSystemStuff
{
	/**
	 * Executes the `getUsername` operation.
	 * @return Result produced by `getUsername`, when applicable.
	 */
	public static function getUsername():String { return "unknown"; }
	/**
	 * Executes the `getUserPath` operation.
	 * @return Result produced by `getUserPath`, when applicable.
	 */
	public static function getUserPath():String { return ""; }
	/**
	 * Executes the `getTempPath` operation.
	 * @return Result produced by `getTempPath`, when applicable.
	 */
	public static function getTempPath():String { return ""; }
	/**
	 * Executes the `executableFileName` operation.
	 * @return Result produced by `executableFileName`, when applicable.
	 */
	public static function executableFileName():String { return ""; }
}
#end
