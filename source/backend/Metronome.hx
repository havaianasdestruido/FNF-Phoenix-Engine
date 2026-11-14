package backend;

import flixel.FlxG;
import flixel.sound.FlxSound;

/**
 * Shared metronome tick for gameplay, the chart editor and latency calibration.
 *
 * The sound belongs to Flixel's normal sound list/group, so it follows the
 * game's master volume and mute state. It is never a substitute for a visual
 * beat indicator on a muted device.
 */
class Metronome
{
  /** No tick. This is the default for new and missing saves. */
  public static inline var OFF:String = 'Off';

  /** Tick only during the countdown lead-in. */
  public static inline var COUNT_IN:String = 'Count-in';

  /** Tick during the countdown and throughout the song. */
  public static inline var ALWAYS:String = 'Always';

  /** Shipped shared sample, resolved through the usual sound/mod fallback. */
  public static inline var SOUND_KEY:String = 'Metronome_Tick';

  /** Allowed values for the Gameplay option, in display order. */
  public static final MODES:Array<String> = [OFF, COUNT_IN, ALWAYS];

  static var tick:FlxSound = null;

  /**
   * Decode the shared sample during loading, without creating a voice.
   * Keeps the first enabled beat from paying the decode cost.
   */
  public static function cache():Void
  {
    Paths.sound(SOUND_KEY);
  }

  /**
   * Restart the tick at the song's playback rate.
   *
   * Reuses one sound voice; state changes destroy Flixel sounds, so reload the
   * voice when necessary.
   * @param playbackRate Current song rate, applied as pitch where supported.
   */
  public static function play(playbackRate:Float = 1):Void
  {
    if (tick == null || !tick.exists) tick = FlxG.sound.load(Paths.sound(SOUND_KEY));
    if (tick == null || !tick.exists) return;

    // Refresh the transform before starting: the master volume may have changed
    // while the reusable voice was idle, and a muted device must stay silent.
    tick.volume = 1;
    #if FLX_PITCH
    tick.pitch = playbackRate;
    #end
    tick.play(true);
  }

  /**
   * Stop immediately on pause, seek or exit.
   * An old tick is never resumed when playback continues.
   */
  public static function stop():Void
  {
    if (tick != null && tick.exists) tick.stop();
  }

  /**
   * Whether a mode permits a tick in the current phase.
   * Unknown saved values fail closed as Off.
   * @param mode Saved ClientPrefs.metronome value.
   * @param inCountdown True for countdown timer beats, false for song beats.
   */
  public static function allowsTick(mode:String, inCountdown:Bool):Bool
  {
    return mode == ALWAYS || (mode == COUNT_IN && inCountdown);
  }
}
