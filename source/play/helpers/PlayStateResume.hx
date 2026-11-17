package play.helpers;

import backend.ClientPrefs;
import backend.Conductor;

import flixel.FlxG;
import flixel.sound.FlxSound;
import flixel.tweens.FlxTween;
import flixel.util.FlxTimer;

import play.PlayState;
import play.helpers.PlayStateCountdown;
import play.helpers.ResumeCountdownMath;
import psychlua.FunkinLua;

/**
 * **Resume countdown** (`ClientPrefs.resumeCountdown`, Options -> Gameplay):
 * after the player unpauses a running song, the engine counts 3-2-1-GO with
 * the same art and sounds the intro countdown uses, and only then resyncs the
 * vocals, reactivates timers/tweens and dispatches `onResume`.
 *
 * ### Why
 *
 * The Resume row lives inside the pause menu; on touch devices the thumb
 * leaves the lanes to get there, and resuming on the same frame steals the
 * first note (or the first beat after a long pause). The countdown gives the
 * thumb a beat of warning instead.
 *
 * ### Which unpauses count
 *
 * Only paths that mean "the player is done pausing" mark the unpause with
 * `PlayState.resumeCountdownWanted` (the Resume row and the unpause `BACK`
 * binding in `states.substates.PauseSubState`). Every other `close()` of the
 * pause substate (End Song, Skip Time forward, charting round trips) skips
 * the countdown entirely, exactly like before this option existed. Even then
 * the countdown only runs when the song was actually running: see
 * `ResumeCountdownMath.shouldRun` — it gates on `paused`, not
 * `startingSong`, `canResync` and not FFmpeg rendering.
 *
 * While the countdown runs, `paused` is still `true` (input ignored, chart
 * frozen) and the countdown ticks on a dedicated `FlxTimer` that stays
 * active while the global timer manager is paused. The tick interval is the
 * song's crochet, clamped to a sane band by
 * `ResumeCountdownMath.tickInterval`.
 *
 * ### Scripts
 *
 * Like the other pause events, the countdown is dispatched to Lua, Python and
 * HScript through `callOnLuas`:
 *
 * - `onResumeCountdownStart()` — fired before the first tick. Returning
 *   `Function_Stop` skips the countdown and resumes immediately.
 * - `onResumeCountdownTick(count)` — fired on every tick: `3`, `2`, `1` and
 *   `0` (GO).
 * - `onResume()` — fired when the song actually resumes (unchanged hook; it
 *   is simply deferred by the countdown).
 *
 * The current state is also published via `setOnScripts`
 * (`resumeCountdownActive`) so scripts can poll it.
 */
@:access(play.PlayState)
class PlayStateResume
{
  /**
   * Starts the countdown and keeps the game frozen until the GO tick.
   *
   * Called from `PlayState.closeSubState()` only for unpause intents that
   * also pass `ResumeCountdownMath.shouldRun`. Callers must leave
   * `resumeCountdownWanted = false` behind; this function does not clear it
   * (the caller owns the flag, this function owns the countdown).
   */
  public static function begin(state:PlayState):Void
  {
    if (state == null) return;

    state.resumeCountdownActive = true;
    state.setOnScripts('resumeCountdownActive', true);

    // Scripts get one veto: skipping the countdown resumes immediately, like
    // the pre-option behaviour.
    final ret:Dynamic = state.hasActiveScripts()
      ? state.callOnLuas('onResumeCountdownStart', null, false)
      : null;
    // `Function_Stop` is the shared sentinel across Lua, Python and HScript.
    if (ret == FunkinLua.Function_Stop)
    {
      finish(state);
      return;
    }

    final tick:Float = ResumeCountdownMath.tickInterval(Conductor.crochet, state.playbackRate);
    final introImages:Array<String> = PlayStateCountdown.introImageSet();
    final antialias:Bool = ClientPrefs.globalAntialiasing && !PlayState.isPixelStage;

    var counter:Int = 0;
    cancelTimer(state);
    state.resumeTimer = new FlxTimer().start(tick, function(tmr:FlxTimer)
    {
      switch (counter)
      {
        case 0:
          playTickSound(state.intro3);
          dispatchTick(state, 3);
        case 1:
          playTickSound(state.intro2);
          PlayStateCountdown.createCountdownSprite(state, introImages[0], antialias);
          dispatchTick(state, 2);
        case 2:
          playTickSound(state.intro1);
          PlayStateCountdown.createCountdownSprite(state, introImages[1], antialias);
          dispatchTick(state, 1);
        case 3:
          playTickSound(state.introGo);
          PlayStateCountdown.createCountdownSprite(state, introImages[2], antialias);
          dispatchTick(state, 0);
        default:
          finish(state);
          return;
      }

      counter += 1;
    }, ResumeCountdownMath.TICK_COUNT);
  }

  /**
   * Performs the actual resume: the same work the instant path does —
   * vocals resync, timers/tweens reactivated, `paused` cleared, `onResume`
   * dispatched. Handles both call shapes:
   *
   * - called directly from `closeSubState()` for pause-substate closes that
   *   do not go through the countdown (the pre-option behaviour);
   * - called from the GO tick (or the script veto) to end a countdown.
   *
   * Safe to call more than once: the second call returns early once
   * `paused` has been cleared.
   */
  public static function finish(state:PlayState):Void
  {
    if (state == null) return;

    cancelTimer(state);
    if (!state.resumeCountdownActive && !state.paused) return; // already resumed

    state.resumeCountdownActive = false;
    state.setOnScripts('resumeCountdownActive', false);

    if (FlxG.sound.music != null && !state.startingSong && state.canResync && !state.ffmpegMode)
      state.resyncVocals();

    FlxTimer.globalManager.forEach(function(tmr:FlxTimer) if (!tmr.finished) tmr.active = true);
    FlxTween.globalManager.forEach(function(twn:FlxTween) if (!twn.finished) twn.active = true);

    state.paused = false;
    if (state.hasActiveScripts()) state.callOnLuas('onResume');
    state.resetRPC(state.startTimer != null && state.startTimer.finished);
  }

  /**
   * Cancels a pending resume countdown (song teardown). The world stays
   * exactly as the countdown left it; a later `setup`/`create` starts fresh.
   */
  public static function cancel(state:PlayState):Void
  {
    if (state == null) return;

    cancelTimer(state);
    if (state.resumeCountdownActive)
    {
      state.resumeCountdownActive = false;
      state.setOnScripts('resumeCountdownActive', false);
    }
  }

  static function cancelTimer(state:PlayState):Void
  {
    if (state.resumeTimer != null)
    {
      state.resumeTimer.cancel();
      state.resumeTimer = null;
    }
  }

  static function playTickSound(sound:FlxSound):Void
  {
    if (sound == null) return;
    sound.volume = FlxG.sound.volume;
    sound.play();
  }

  static function dispatchTick(state:PlayState, count:Int):Void
  {
    if (state.hasActiveScripts()) state.callOnLuas('onResumeCountdownTick', [count]);
  }
}
