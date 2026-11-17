package play.helpers;

/**
 * Renderer-free rules behind the **Resume countdown** preference
 * (`ClientPrefs.resumeCountdown`, Options -> Gameplay).
 *
 * When the player unpauses a song that is actually running, the engine counts
 * 3-2-1(-GO) instead of resyncing the vocals at once, so thumbs that left the
 * lanes to press Resume get a beat to get back. The cosmetic half (sprites,
 * sounds, script dispatch) lives in `play.helpers.PlayStateResume`; this is
 * the part `tests/haxe/run-resume-countdown.sh` can execute without Flixel.
 */
class ResumeCountdownMath
{
  /** Ticks: 3, 2, 1 and the GO flourish; the resume itself happens on the last one. */
  public static inline var TICK_COUNT:Int = 5;

  /** Slowest tick: a very slow chart must not park the player for a second per number. */
  public static inline var MAX_TICK_SECONDS:Float = 0.75;

  /** Fastest tick: guards against absurd BPMs producing a sub-frame countdown. */
  public static inline var MIN_TICK_SECONDS:Float = 0.15;

  /** Tick interval used when the chart data is unusable (NaN / non-positive BPM). */
  public static inline var FALLBACK_TICK_SECONDS:Float = 0.5;

  /**
   * Whether the resume countdown should run instead of resuming instantly.
   *
   * Mirrors the instant-resume path this replaces: an unpause only counts as
   * "the song was running" when the substate actually paused gameplay
   * (`paused`), the song is not still in its intro countdown
   * (`startingSong`), the engine is allowed to resync the vocals
   * (`canResync` — death round trips, skip-time seeks, chart playtest round
   * trips) and the FFmpeg renderer is not driving frame pacing. Everything
   * else resumes exactly like it did before this option existed.
   */
  public static function shouldRun(resumeCountdown:Bool, paused:Bool, startingSong:Bool, canResync:Bool, ffmpegMode:Bool):Bool
  {
    return resumeCountdown && paused && !startingSong && canResync && !ffmpegMode;
  }

  /**
   * Seconds per tick, derived from the chart's crochet (one beat) so the
   * countdown feels like part of the song, clamped to a sane band.
   *
   * @param crochetMs    `Conductor.crochet` in milliseconds.
   * @param playbackRate the current playback rate; values outside `> 0` and
   *                     finite fall back to 1.
   */
  public static function tickInterval(crochetMs:Float, playbackRate:Float):Float
  {
    final rate:Float = (playbackRate != playbackRate || !(playbackRate > 0) || playbackRate > 1000) ? 1 : playbackRate;
    final interval:Float = crochetMs / 1000 / rate;

    if (interval != interval || !(interval > 0))
      return FALLBACK_TICK_SECONDS;
    if (interval > MAX_TICK_SECONDS) return MAX_TICK_SECONDS;
    if (interval < MIN_TICK_SECONDS) return MIN_TICK_SECONDS;
    return interval;
  }
}
