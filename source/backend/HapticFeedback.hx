package backend;

import android.platform.AndroidHaptics;

/**
 * Opt-in gameplay vibration and the shared pulse used by script callbacks.
 * The mode strings are also the choices in Options -> Mobile Options.
 */
class HapticFeedback
{
  public static inline var OFF:String = 'Off';
  public static inline var MISSES:String = 'Misses';
  public static inline var HITS_AND_MISSES:String = 'Hits and Misses';
  public static final CHOICES:Array<String> = [OFF, MISSES, HITS_AND_MISSES];

  public static inline var DEFAULT_DURATION_MS:Int = 50;
  public static inline var MAX_DURATION_MS:Int = 5000;
  public static inline var HIT_DURATION_MS:Int = 15;
  public static inline var MISS_DURATION_MS:Int = 70;

  /** Milliseconds for a player note event; unknown or disabled modes return zero. */
  public static function durationFor(mode:String, hit:Bool):Int
  {
    return switch (mode)
    {
      case MISSES: hit ? 0 : MISS_DURATION_MS;
      case HITS_AND_MISSES: hit ? HIT_DURATION_MS : MISS_DURATION_MS;
      default: 0;
    }
  }

  /**
   * Normalize a script-supplied duration. Lua numbers arrive as floats, while
   * Python may supply an integer. Null/omitted means the default; invalid,
   * non-finite and non-positive values do not vibrate. Fractions are rounded.
   */
  public static function sanitizeDuration(value:Dynamic):Int
  {
    final duration:Float = value == null ? DEFAULT_DURATION_MS : Std.parseFloat(Std.string(value));
    if (!Math.isFinite(duration) || duration <= 0) return 0;
    return Std.int(Math.min(MAX_DURATION_MS, Math.round(duration)));
  }

  /**
   * Send one explicit pulse, returning whether it reached the Android bridge.
   * Script calls are deliberate effects, independent of the automatic note
   * feedback mode. Other targets are no-ops; Android's bridge safely ignores
   * devices without a vibrator.
   */
  public static function pulse(durationMs:Dynamic = DEFAULT_DURATION_MS):Bool
  {
    final duration:Int = sanitizeDuration(durationMs);
    if (duration == 0 || !PlatformSupport.supports([PlatformSupport.ANDROID])) return false;
    AndroidHaptics.vibrate(duration);
    return true;
  }

  /** Stop an in-flight pulse when gameplay is covered, backgrounded or exited. */
  public static function cancel():Void
  {
    if (PlatformSupport.supports([PlatformSupport.ANDROID])) AndroidHaptics.cancel();
  }
}
