package play.helpers;

/**
 * Early/late classification of a judged note, ported from Mic'd Up!.
 *
 * The judged difference is `strumTime - songPosition + ratingOffset`, so a
 * **positive** value means the player pressed the key before the note's time
 * (early) and a **negative** one means they pressed after it (late). Hits that
 * land inside a small dead zone around zero are "on time": with the Mic'd Up!
 * value of 10% of the hit window, a hit within +-10% of `safeZoneOffset` gets no
 * label at all instead of flickering between early and late.
 *
 * Kept free of Flixel/OpenFL imports so the rules can be asserted directly in
 * `tests/haxe/HitTimingSpec.hx` without a renderer.
 */
class HitTiming
{
  public static inline var EARLY:String = 'early';
  public static inline var LATE:String = 'late';
  public static inline var NONE:String = '';

  /** Share of the hit window that still counts as "on time" (Mic'd Up! uses 10%). */
  public static inline var DEADZONE_PERCENT:Float = 0.1;

  /** Text shown by the simple (`JudgeText`) and MS popups. */
  public static inline var EARLY_LABEL:String = 'Early';
  public static inline var LATE_LABEL:String = 'Late';

  /**
   * Half-width of the "on time" dead zone, in the same milliseconds as `window`.
   *
   * @param window  hit window to scale, normally `Conductor.safeZoneOffset`.
   * @param percent share of `window` that is neutral; invalid values fall back
   *                to {@link DEADZONE_PERCENT}.
   * @return `0` when the window is not usable (zero, negative or `NaN`).
   */
  public static function deadzone(window:Float, percent:Float = DEADZONE_PERCENT):Float
  {
    if (Math.isNaN(window) || window <= 0) return 0;
    final share:Float = (Math.isNaN(percent) || percent <= 0 || percent >= 1) ? DEADZONE_PERCENT : percent;
    return window * share;
  }

  /**
   * Classifies one judged note.
   *
   * @param noteDiff signed difference in milliseconds (`+` early, `-` late).
   * @param window   hit window the dead zone is derived from.
   * @return {@link EARLY}, {@link LATE} or {@link NONE} when the hit is on time
   *         or the values cannot be classified.
   */
  public static function classify(noteDiff:Float, window:Float, percent:Float = DEADZONE_PERCENT):String
  {
    if (Math.isNaN(noteDiff) || Math.isNaN(window) || window <= 0) return NONE;

    final zone:Float = deadzone(window, percent);
    if (noteDiff > zone) return EARLY;
    if (noteDiff < -zone) return LATE;
    return NONE;
  }

  /** Whether `timing` is a label worth drawing. */
  public static inline function isTiming(timing:String):Bool
  {
    return timing == EARLY || timing == LATE;
  }

  /**
   * Human-readable form used by the text popups.
   *
   * @return `"Early"`, `"Late"` or an empty string for {@link NONE}.
   */
  public static function label(timing:String):String
  {
    return switch (timing)
    {
      case EARLY: EARLY_LABEL;
      case LATE: LATE_LABEL;
      default: NONE;
    }
  }
}
