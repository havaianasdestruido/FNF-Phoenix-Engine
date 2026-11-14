package backend;

/**
 * Renderer-free rules behind `ClientPrefs.menuMusicVolume` and the optional
 * menu music fade.
 *
 * The menu theme is mixed separately from gameplay audio: the preference
 * scales only `FlxG.sound.music` while it is a menu track, and the global
 * sound volume (the volume keys, `objects.CustomSoundTray`) still multiplies
 * on top of it. `backend.MenuMusic` is the Flixel-facing half that applies
 * these rules.
 *
 * No Flixel, OpenFL or Lime imports, so `tests/haxe/MenuMusicSpec.hx` can
 * interpret this module in CI without the game's haxelibs -- the same trick
 * `backend.HoldToConfirmLogic` uses for the hold-to-confirm gestures.
 */
class MenuMusicLogic
{
  /** Volume used when a saved preference is missing, not a number or negative. */
  public static inline var DEFAULT_VOLUME:Float = 1;

  /** Length of a full fade (silence <-> full volume), in seconds. */
  public static inline var FULL_FADE_SECONDS:Float = 0.8;

  /** A fade shorter than this is not worth starting; the track is cut instead. */
  public static inline var MIN_FADE_SECONDS:Float = 0.05;

  /** Smallest volume difference that still counts as a move. */
  public static inline var EPSILON:Float = 0.001;

  /** Quietest audible volume. */
  public static inline var MIN_VOLUME:Float = 0;

  /** Loudest menu volume; the global sound volume can only make it quieter. */
  public static inline var MAX_VOLUME:Float = 1;

  /**
   * Volume a menu track should play at, from the raw preference value.
   *
   * Out-of-range saves clamp into 0..1, while a missing, NaN or negative value
   * falls back to `DEFAULT_VOLUME`: a hand-edited save must not be able to
   * mute the menus permanently, and `0` still means silence when the player
   * really picked it.
   */
  public static function volume(pref:Null<Float>):Float
  {
    if (pref == null || Math.isNaN(pref) || pref < MIN_VOLUME) return DEFAULT_VOLUME;
    return pref > MAX_VOLUME ? MAX_VOLUME : pref;
  }

  /**
   * Highest volume a menu state's own ramp may reach.
   *
   * Several states fade the menu theme in themselves and stop at a fixed
   * ceiling (`0.8` in the main menu, `0.7` in Freeplay and Credits). Those
   * ramps used to override the preference, so they now ask for the smaller of
   * that ceiling and the preferred volume.
   */
  public static function rampCap(cap:Float, pref:Null<Float>):Float
  {
    final limit:Float = volume(pref);
    if (Math.isNaN(cap) || cap >= limit) return limit;
    return cap < MIN_VOLUME ? MIN_VOLUME : cap;
  }

  /** Whether a move between two volumes deserves a tween at all. */
  public static function shouldFade(enabled:Bool, from:Float, to:Float):Bool
  {
    if (!enabled) return false;
    return Math.abs(clampVolume(to) - clampVolume(from)) > EPSILON;
  }

  /**
   * Fade length for a move from `from` to `to`, in seconds.
   *
   * Proportional to the distance, so a nearly silent track does not spend a
   * whole fade on the last few percent. `0` means "no fade: cut now".
   */
  public static function fadeSeconds(from:Float, to:Float, ?enabled:Bool = true):Float
  {
    if (!shouldFade(enabled, from, to)) return 0;
    final seconds:Float = FULL_FADE_SECONDS * Math.abs(clampVolume(to) - clampVolume(from));
    return seconds < MIN_FADE_SECONDS ? 0 : seconds;
  }

  /**
   * One linear step of a manual (per-frame) ramp, never overshooting
   * `target`. `speed` is in volume per second. Invalid input (NaN, a
   * non-positive speed, a frozen frame) leaves the volume untouched.
   */
  public static function step(current:Float, target:Float, elapsed:Float, speed:Float):Float
  {
    if (!isFinite(current) || !isFinite(target) || !isFinite(elapsed) || !isFinite(speed)) return current;
    if (elapsed <= 0 || speed <= 0) return current;

    final delta:Float = speed * elapsed;
    if (Math.abs(target - current) <= delta) return target;
    return current < target ? current + delta : current - delta;
  }

  /** Clamp to the audible range; NaN becomes silence because nothing plays. */
  static function clampVolume(value:Float):Float
  {
    if (Math.isNaN(value) || value < MIN_VOLUME) return MIN_VOLUME;
    return value > MAX_VOLUME ? MAX_VOLUME : value;
  }

  static inline function isFinite(value:Float):Bool
  {
    return !Math.isNaN(value) && value != Math.POSITIVE_INFINITY && value != Math.NEGATIVE_INFINITY;
  }
}
