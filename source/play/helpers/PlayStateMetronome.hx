package play.helpers;

import backend.ClientPrefs;
import backend.Conductor;
import backend.Metronome;
import play.PlayState;

/**
 * Keeps the optional metronome aligned with countdown and song beats.
 *
 * The countdown timer and PlayState.beatHit share one beat identity so START
 * is not clicked twice and seeks do not replay skipped beats.
 */
@:access(play.PlayState)
class PlayStateMetronome
{
  /** Preload the sample only when the saved mode can actually use it. */
  public static function cache(state:PlayState):Void
  {
    if (ClientPrefs.metronome != Metronome.OFF) Metronome.cache();
  }

  /**
   * The countdown timer owns all five lead-in beats, including START.
   * @param counter Countdown callback index, from 0 through 4.
   */
  public static function countdownTick(state:PlayState, counter:Int):Void
  {
    if (state.startingSong) playBeat(state, counter - 4, true);
  }

  /**
   * Called once per song beat; Count-in mode is silent here.
   * Also absorbs the first beat crossed after a startOnTime seek.
   */
  public static function beatHit(state:PlayState):Void
  {
    if (state.startingSong) return;

    // A chart-editor seek plays a short lead-in, then startSong settles the
    // stems. Do not tick through either jump or replay the beats skipped by it.
    if (state.metronomeResumeTime != null)
    {
      if (Conductor.songPosition < state.metronomeResumeTime) return;
      state.metronomeResumeTime = null;
      state.lastMetronomeBeat = state.curBeat;
      return;
    }

    playBeat(state, state.curBeat, false);
  }

  /**
   * Reset beat identity at a seek and suppress the startOnTime lead-in.
   * Called after Conductor.songPosition has been moved to the lead-in time.
   */
  public static function seek(state:PlayState):Void
  {
    Metronome.stop();
    state.lastMetronomeBeat = -1;
    state.metronomeResumeTime = PlayState.startOnTime > 0 ? PlayState.startOnTime : null;
  }

  static function playBeat(state:PlayState, beat:Int, inCountdown:Bool):Void
  {
    if (!Metronome.allowsTick(ClientPrefs.metronome, inCountdown)) return;
    if (PlayState.startOnTime > 0 || state.metronomeResumeTime != null) return;
    if (!state.startedCountdown || state.paused || state.endingSong || state.isDead || state.transitioning || state.inCutscene || state.ffmpegMode
      || state.finishTimer != null) return;
    if (state.lastMetronomeBeat == beat) return;

    state.lastMetronomeBeat = beat;
    Metronome.play(state.playbackRate);
  }
}
