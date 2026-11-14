package backend;

/**
 * The volume curve shared by the sound tray (`objects.CustomSoundTray`) and
 * Options -> Audio -> Master Volume (`ClientPrefs.masterVolume`).
 *
 * `FlxG.sound.volume` is **not** a linear loudness value: the tray has always
 * stored a logarithmic one, so a step in the middle of the slider is much
 * quieter than "half volume" would suggest. Half of the tray is a volume of
 * about `0.03`, and `0.001` is the quietest step it can reach (`-60 dB`).
 *
 * Both ends therefore have to agree on the same mapping, otherwise the row and
 * the volume keys would disagree about the same number. `toVolume()` is the
 * slider position -> `FlxG.sound.volume` direction (what the tray's
 * `changeVolume()` does when it adds its step) and `toPercent()` is the inverse
 * (what the tray uses to pick how many bars to draw).
 *
 * The module is deliberately free of Flixel/OpenFL/Lime imports so the mapping
 * runs under the Haxe interpreter in `tests/haxe/VolumeCurveSpec.hx`.
 */
class VolumeCurve
{
  /** Quietest step the tray can reach; also the curve's `minValue`. */
  public static inline var MIN_VOLUME:Float = 0.001;

  /** Bars the tray draws (`assets/soundtray/images/bars_10.png`). */
  public static inline var TRAY_STEPS:Int = 10;

  /**
   * Slider position (`0..1`, also the option's percentage) to the volume
   * Flixel multiplies every `FlxSound` by.
   *
   * `1` is full volume, `0.5` is the tray's halfway point (~`0.0316`), and
   * `0` is real silence: the row can mute the game even though the volume
   * keys stop at {@link MIN_VOLUME}. Values outside `0..1` are clamped.
   */
  public static function toVolume(percent:Float):Float
  {
    final position:Float = clamp01(percent);
    if (position <= 0) return 0;
    return Math.exp(Math.log(MIN_VOLUME) * (1 - position));
  }

  /**
   * Inverse of {@link toVolume}: the slider position (`0..1`) for a volume.
   *
   * `FlxG.sound.volume == 0` (and anything at or below {@link MIN_VOLUME})
   * reads as `0`, which matches the empty tray.
   */
  public static function toPercent(volume:Float):Float
  {
    final level:Float = clamp01(volume);
    if (level <= MIN_VOLUME) return 0;
    return 1 - (Math.log(level) / Math.log(MIN_VOLUME));
  }

  /**
   * One `+`/`-` step of the volume keys, on the same curve.
   *
   * Unlike {@link toVolume}, the bottom of the curve is the tray's usual floor
   * ({@link MIN_VOLUME}, about -60 dB) rather than real silence: that is what the
   * keys have always done, and it keeps the tray from sticking on screen (its
   * auto-hide timer only runs while the volume is above 0).
   */
  public static function steppedVolume(volume:Float, amount:Float):Float
  {
    final position:Float = toPercent(volume) + amount;
    return (position <= 0) ? MIN_VOLUME : toVolume(position);
  }

  /** How many of the tray's bars should light up for this volume (`0..10`). */
  public static function traySteps(volume:Float):Int
  {
    final steps:Int = Std.int(Math.round(toPercent(volume) * TRAY_STEPS));
    if (steps < 0) return 0;
    return (steps > TRAY_STEPS) ? TRAY_STEPS : steps;
  }

  /** Clamps to `0..1`, mapping `NaN` and infinities to a usable value. */
  public static function clamp01(value:Float):Float
  {
    // NaN first: every comparison against it is false, so the checks below
    // would let it through.
    if (Math.isNaN(value)) return 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }
}
