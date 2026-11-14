package play.helpers;

import backend.ClientPrefs;
import backend.HapticFeedback;
import play.PlayState;

/** Automatic, preference-controlled vibration for player note events. */
@:access(play.PlayState)
class PlayStateHaptics
{
  /** A successful player note head. Sustain ticks are filtered by the callers. */
  public static function hit(state:PlayState):Void
  {
    pulse(state, true);
  }

  /** A dropped note, hurt note or ghost miss. */
  public static function miss(state:PlayState):Void
  {
    pulse(state, false);
  }

  /** Stop native feedback when a menu covers the song or the app loses focus. */
  public static function cancel():Void
  {
    HapticFeedback.cancel();
  }

  static function pulse(state:PlayState, hit:Bool):Void
  {
    if (state == null || state.paused || state.endingSong || state.isDead || state.inCutscene || state.transitioning || state.ffmpegMode
      || state.subState != null) return;

    final duration:Int = HapticFeedback.durationFor(ClientPrefs.hapticFeedback, hit);
    if (duration > 0) HapticFeedback.pulse(duration);
  }
}
