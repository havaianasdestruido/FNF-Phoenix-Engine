package backend;

typedef AccuracyWindowSet =
{
  var perfect:Float;
  var sick:Float;
  var good:Float;
  var bad:Float;
  var safeFrames:Float;
}

typedef AccuracyBounds =
{
  var perfectMin:Float;
  var perfectMax:Float;
  var sickMin:Float;
  var sickMax:Float;
  var goodMin:Float;
  var goodMax:Float;
  var badMin:Float;
  var badMax:Float;
}

/**
 * Pure data and helpers for hit-window presets (`ClientPrefs.accuracyPreset`).
 *
 * Kept free of Flixel imports so `tests/haxe` can exercise preset lookup,
 * reverse detection after single-row tweaks, and neighbour bound clamping
 * under `--interp`.
 *
 * All built-in presets keep `safeFrames <= 10.0` because `PlayStatePlayback`
 * suppresses highscore saving whenever `safeFrames > 10`.
 */
class AccuracyPresets
{
  public static inline var VANILLA:String = 'Vanilla';
  public static inline var PSYCH:String = 'Psych';
  public static inline var KADE:String = 'Kade';
  public static inline var ITG:String = 'ITG';
  public static inline var CUSTOM:String = 'Custom';

  public static inline var DEFAULT_PERFECT:Float = 15.0;
  public static inline var DEFAULT_SICK:Float = 45.0;
  public static inline var DEFAULT_GOOD:Float = 90.0;
  public static inline var DEFAULT_BAD:Float = 135.0;
  public static inline var DEFAULT_SAFE_FRAMES:Float = 10.0;

  public static inline var MIN_PERFECT_WINDOW:Float = 1.0;
  public static inline var MAX_BAD_WINDOW:Float = 165.0;
  public static inline var MATCH_EPSILON:Float = 0.05;

  public static final NAMES:Array<String> = [VANILLA, PSYCH, KADE, ITG, CUSTOM];

  /** Resolves a saved or user-supplied preset label to one of `NAMES`. */
  public static function normalize(name:Null<String>):String
  {
    if (name == null) return PSYCH;
    return switch (StringTools.trim(name).toLowerCase())
    {
      case 'vanilla', 'fnf': VANILLA;
      case 'psych', 'js', 'phoenix', 'default', '': PSYCH;
      case 'kade', 'ke': KADE;
      case 'itg', 'stepmania': ITG;
      case 'custom': CUSTOM;
      default: CUSTOM;
    };
  }

  /**
   * Returns the five timing values for a built-in preset, or `null` for
   * `CUSTOM` (where individual window fields stay untouched).
   */
  public static function windowsFor(preset:Null<String>):Null<AccuracyWindowSet>
  {
    return switch (normalize(preset))
    {
      case VANILLA:
        {
          perfect: 16.5,
          sick: 33.0,
          good: 125.0,
          bad: 150.0,
          safeFrames: 10.0
        };
      case PSYCH:
        {
          perfect: DEFAULT_PERFECT,
          sick: DEFAULT_SICK,
          good: DEFAULT_GOOD,
          bad: DEFAULT_BAD,
          safeFrames: DEFAULT_SAFE_FRAMES
        };
      case KADE:
        {
          perfect: 22.5,
          sick: 45.0,
          good: 90.0,
          bad: 135.0,
          safeFrames: 10.0
        };
      case ITG:
        {
          perfect: 21.5,
          sick: 43.0,
          good: 102.0,
          bad: 135.0,
          safeFrames: 10.0
        };
      default:
        null;
    };
  }

  /**
   * Finds the named preset matching the current five timing values, or
   * `CUSTOM` when any window or `safeFrames` has been adjusted away from a
   * built-in preset.
   */
  public static function detect(perfect:Float, sick:Float, good:Float, bad:Float, safeFrames:Float):String
  {
    for (name in [PSYCH, VANILLA, KADE, ITG])
    {
      final set:Null<AccuracyWindowSet> = windowsFor(name);
      if (set != null
        && approxEqual(perfect, set.perfect)
        && approxEqual(sick, set.sick)
        && approxEqual(good, set.good)
        && approxEqual(bad, set.bad)
        && approxEqual(safeFrames, set.safeFrames))
      {
        return name;
      }
    }
    return CUSTOM;
  }

  /**
   * Computes strictly ordered `minValue` / `maxValue` bounds for the four hit
   * window rows so adjacent windows cannot cross in `GameplaySettingsSubState`.
   */
  public static function bounds(perfect:Float, sick:Float, good:Float, bad:Float):AccuracyBounds
  {
    final pMax:Float = Math.max(MIN_PERFECT_WINDOW, sick - 1.0);
    final sMin:Float = Math.max(MIN_PERFECT_WINDOW + 1.0, perfect + 1.0);
    final sMax:Float = Math.max(sMin, good - 1.0);
    final gMin:Float = Math.max(sMin + 1.0, sick + 1.0);
    final gMax:Float = Math.max(gMin, bad - 1.0);
    final bMin:Float = Math.max(gMin + 1.0, good + 1.0);
    final bMax:Float = Math.max(bMin, MAX_BAD_WINDOW);
    return {
      perfectMin: MIN_PERFECT_WINDOW,
      perfectMax: pMax,
      sickMin: sMin,
      sickMax: sMax,
      goodMin: gMin,
      goodMax: gMax,
      badMin: bMin,
      badMax: bMax
    };
  }

  /** Formats the `Safe Frames` option display string, warning above 10 frames. */
  public static inline function safeFramesDisplayFormat(safeFrames:Float):String
  {
    return safeFrames > 10.0 ? '%v (Will not save)' : '%v';
  }

  static inline function approxEqual(a:Float, b:Float):Bool
  {
    return !Math.isNaN(a) && !Math.isNaN(b) && Math.abs(a - b) <= MATCH_EPSILON;
  }
}
