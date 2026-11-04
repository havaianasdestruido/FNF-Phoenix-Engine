package backend;

import flixel.FlxG;

/**
 * Everything the engine needs to know about how dense the player's screen is.
 *
 * Two different numbers matter and they are easy to mix up:
 *
 * - `dpi()` is the *physical* density of the panel (96 on a classic monitor,
 *   ~440 on a modern phone). UI that should keep its real-world size grows
 *   with it;
 * - `pixelsPerGamePixel()` is how many device pixels one of the game's 1280x720
 *   logical pixels covers right now. Anything rasterised on the fly (the
 *   platform badge on the watermark) must multiply its bitmap by this or it
 *   shows up soft on a 4K/HiDPI window.
 *
 * The DPI lookup is cached because Android answers it through JNI; call
 * `invalidate()` whenever the window may have moved to another display.
 */
class ScreenDensity
{
  /** Anything above this is a driver reporting nonsense, not a real panel. */
  static inline var MAX_PLAUSIBLE_DPI:Float = 1200;

  static var cachedDpi:Float = -1;

  /** Drops the cached DPI so the next query hits the display again. */
  public static function invalidate():Void
  {
    cachedDpi = -1;
  }

  /** Physical pixel density of the display the game is on. */
  public static function dpi():Float
  {
    if (cachedDpi > 0) return cachedDpi;

    var value:Float = 0;

    #if android
    // Android's density bucket is what the system lays its own UI out with,
    // so it matches what the player is used to better than the raw panel DPI.
    try
    {
      final info = android.platform.AndroidDisplay.getInfo();
      if (info != null && info.densityDpi > 0) value = info.densityDpi;
    }
    catch (_:Dynamic) {}
    #end

    #if (lime && !flash)
    if (!(value > 0))
    {
      try
      {
        final display = lime.system.System.getDisplay(0);
        if (display != null && display.dpi > 0) value = display.dpi;
      }
      catch (_:Dynamic) {}
    }
    #elseif flash
    if (!(value > 0))
    {
      try
      {
        value = flash.system.Capabilities.screenDPI;
      }
      catch (_:Dynamic) {}
    }
    #end

    if (!(value > 0) || value > MAX_PLAUSIBLE_DPI) value = baselineDpi();
    cachedDpi = value;
    return value;
  }

  /** The density a target is authored for: 160 (`mdpi`) on phones, 96 elsewhere. */
  public static function baselineDpi():Float
  {
    #if mobile
    return PlatformIcons.MOBILE_BASELINE_DPI;
    #else
    return PlatformIcons.DESKTOP_BASELINE_DPI;
    #end
  }

  /** How much bigger density-aware UI should be drawn on this screen. */
  public static function scale():Float
  {
    return PlatformIcons.densityScale(dpi(), baselineDpi());
  }

  /**
   * Device pixels covered by one game pixel: the window's scale mode factor
   * times the HiDPI backing scale of the window itself.
   */
  public static function pixelsPerGamePixel():Float
  {
    var ratio:Float = 1;

    try
    {
      if (FlxG.scaleMode != null && FlxG.scaleMode.scale != null && FlxG.scaleMode.scale.x > 0) ratio = FlxG.scaleMode.scale.x;
    }
    catch (_:Dynamic) {}

    #if !flash
    try
    {
      if (FlxG.stage != null && FlxG.stage.window != null && FlxG.stage.window.scale > 0) ratio *= FlxG.stage.window.scale;
    }
    catch (_:Dynamic) {}
    #end

    return ratio > 0 ? ratio : 1;
  }
}
