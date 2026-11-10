package backend;

#if (cpp && linux && !android)
/**
 * hxcpp bridge to `native/src/phoenix_refresh_rate.cpp`, ported from Troll
 * Engine's `funkin.api.Linux`. Use `MonitorRefreshRate.get()` instead.
 */
@:buildXml('<include name="../../../../source/backend/native/refresh_rate_build.xml" />')
@:include("phoenix_refresh_rate.h")
@:noCompletion
extern class MonitorRefreshRateNative
{
  @:native("phoenixMonitorRefreshRate")
  static function query():Int;
}
#end

/**
 * Refresh rate of the monitor the game is running on, in Hz.
 *
 * On desktop Linux the rate is asked from the X server (X11/XWayland through
 * RandR), which is the part ported from Troll Engine. Everywhere else, and
 * whenever that query has no answer, Lime's display mode is used.
 */
class MonitorRefreshRate
{
  /** Returned when neither the native query nor Lime reports a usable rate. */
  public static inline final FALLBACK:Int = 60;

  /** Current refresh rate in Hz. Always positive; `FALLBACK` if unknown. */
  public static function get():Int
    return pick(queryNative(), queryLime());

  /**
   * Rate reported by the X server on desktop Linux, in Hz. Zero on any other
   * target, on a Wayland-only or headless session, or without RandR.
   */
  public static function queryNative():Int
  {
    #if (cpp && linux && !android)
    return MonitorRefreshRateNative.query();
    #else
    return 0;
    #end
  }

  /** Rate from Lime's display mode, in Hz. Zero when there is no window yet. */
  public static function queryLime():Int
  {
    #if macro
    return 0;
    #else
    final app = lime.app.Application.current;
    final window = app != null ? app.window : null;
    final mode = window != null ? window.displayMode : null;
    return mode != null ? mode.refreshRate : 0;
    #end
  }

  /** First positive rate of the native and Lime readings, else `FALLBACK`. */
  public static function pick(nativeRate:Int, limeRate:Int):Int
  {
    if (nativeRate > 0) return nativeRate;
    if (limeRate > 0) return limeRate;
    return FALLBACK;
  }
}
