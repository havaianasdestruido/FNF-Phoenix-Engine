import backend.ClientPrefs;
import backend.Conductor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.sound.FlxSound;
import flixel.util.FlxTimer;
import play.PlayState;
import play.helpers.PlayStateResume;
import play.helpers.ResumeCountdownMath;

/**
 * Resume countdown contract: the pure gate/interval math plus the countdown's
 * lifecycle on a stubbed PlayState — which unpauses count, the tick order, the
 * script veto, and the deferred `onResume`.
 *
 * Runs against small stubs, so it needs no game haxelibs:
 *
 *     bash tests/haxe/run-resume-countdown.sh
 */
class ResumeCountdownSpec
{
  static var failures:Int = 0;

  static function check(ok:Bool, label:String, ?pos:haxe.PosInfos):Void
  {
    if (ok) return;
    failures++;
    Sys.println('FAIL: ' + label + ' @' + (pos == null ? 0 : pos.lineNumber));
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    check(Math.abs(actual - expected) < 0.001, '$label (expected $expected, got $actual)');
  }

  static function main():Void
  {
    // The vocal-resync guard reads the music slot; park a sound in it.
    FlxG.sound.music = new FlxSound();

    shouldRunTruthTable();
    tickIntervalMath();
    beginStartsCountdown();
    scriptVetoSkipsCountdown();
    instantResumeWithoutCountdown();
    finishIsIdempotent();
    cancelDropsCountdown();
    offPreferenceResumesInstantly();

    if (failures > 0)
    {
      Sys.println('ResumeCountdownSpec: $failures failure(s)');
      Sys.exit(1);
    }
    Sys.println('ResumeCountdownSpec: PASS');
  }

  /** Only a real unpause of a running song counts as one. */
  static function shouldRunTruthTable():Void
  {
    check(ResumeCountdownMath.shouldRun(true, true, false, true, false), 'a running song counts down');
    check(!ResumeCountdownMath.shouldRun(false, true, false, true, false), 'the preference off resumes instantly');
    check(!ResumeCountdownMath.shouldRun(true, false, false, true, false), 'not paused never counts down');
    check(!ResumeCountdownMath.shouldRun(true, true, true, true, false), 'the intro countdown never double-counts');
    check(!ResumeCountdownMath.shouldRun(true, true, false, false, false), 'a blocked resync never counts down');
    check(!ResumeCountdownMath.shouldRun(true, true, false, true, true), 'FFmpeg rendering never counts down');
  }

  /** The tick follows the chart's crochet, clamped to a sane band. */
  static function tickIntervalMath():Void
  {
    near(ResumeCountdownMath.tickInterval(500, 1), 0.5, 'one beat at crochet 500ms');
    near(ResumeCountdownMath.tickInterval(500, 2), 0.25, 'playback rate speeds the tick up');
    near(ResumeCountdownMath.tickInterval(15000, 1), ResumeCountdownMath.MAX_TICK_SECONDS, 'an absurdly slow chart clamps to the max');
    near(ResumeCountdownMath.tickInterval(50, 1), ResumeCountdownMath.MIN_TICK_SECONDS, 'an absurdly fast chart clamps to the min');
    near(ResumeCountdownMath.tickInterval(Math.NaN, 1), ResumeCountdownMath.FALLBACK_TICK_SECONDS, 'a broken crochet falls back');
    near(ResumeCountdownMath.tickInterval(500, Math.NaN), 0.5, 'a broken playback rate counts as 1x');
    near(ResumeCountdownMath.tickInterval(500, 0), 0.5, 'a zero playback rate counts as 1x');
    near(ResumeCountdownMath.tickInterval(-500, 1), ResumeCountdownMath.FALLBACK_TICK_SECONDS, 'a negative crochet falls back');
    near(ResumeCountdownMath.tickInterval(500, -2), 0.5, 'a negative playback rate counts as 1x');
  }

  /** The countdown opens with tick 3 and resumes only on GO. */
  static function beginStartsCountdown():Void
  {
    Conductor.crochet = 500;
    ClientPrefs.resumeCountdown = true;

    final state = new PlayState();
    // With no scripts loaded the hooks never dispatch; enable them so the
    // spec can observe the tick payloads.
    state.scriptsEnabled = true;
    PlayStateResume.begin(state);

    check(state.resumeCountdownActive, 'the countdown opens the frozen window');
    check(state.scriptVariables.get('resumeCountdownActive') == true, 'scripts are told the countdown started');
    check(state.resumeTimer != null, 'a dedicated timer drives the ticks');
    check(state.paused, 'the chart stays frozen');
    check(state.resyncVocalsCalls == 0, 'vocals are not resynced early');
    check(state.scriptLog.indexOf('onResume') < 0, 'onResume does not fire before GO');

    state.resumeTimer.simulate(1); // tick 0 -> music 3
    check(state.resumeCountdownActive, 'tick 3 keeps the countdown open');
    check(state.intro3.playedCount == 1, 'the 3 sound played');
    check(state.intro2.playedCount == 0, 'the 2 sound has not played');
    near(state.createdSprites.length, 0, 'no art shows on the first tick');

    state.resumeTimer.simulate(1); // tick 1 -> music 2 + ready art
    check(state.createdSprites.length == 1 && state.createdSprites[0] == 'ready', 'tick 2 shows the ready art');
    check(state.scriptLog.indexOf('onResumeCountdownTick:3') >= 0, 'tick 3 was dispatched');

    state.resumeTimer.simulate(1); // tick 2 -> music 1 + set art
    check(state.createdSprites.length == 2 && state.createdSprites[1] == 'set', 'tick 1 shows the set art');

    state.resumeTimer.simulate(1); // tick 3 -> music GO + go art
    check(state.createdSprites.length == 3 && state.createdSprites[2] == 'go', 'tick 0 shows the go art');
    check(state.paused, 'the song is still frozen before the GO tick lands');

    state.resumeTimer.simulate(1); // tick 4 -> resume
    check(!state.resumeCountdownActive, 'GO closes the countdown window');
    check(state.scriptVariables.get('resumeCountdownActive') == false, 'scripts are told the countdown ended');
    check(!state.paused, 'the chart is live again');
    check(state.resyncVocalsCalls == 1, 'vocals resync exactly once');
    check(state.resetRPCCalls == 1, 'the Discord presence resets');
    check(state.scriptLog.indexOf('onResumeCountdownTick:3') >= 0
      && state.scriptLog.indexOf('onResumeCountdownTick:2') >= 0
      && state.scriptLog.indexOf('onResumeCountdownTick:1') >= 0
      && state.scriptLog.indexOf('onResumeCountdownTick:0') >= 0, 'all four ticks dispatched');
    check(state.scriptLog.indexOf('onResume') >= 0, 'onResume fires at the true resume');
    check(state.intro3.playedCount == 1 && state.intro2.playedCount == 1 && state.intro1.playedCount == 1 && state.introGo.playedCount == 1,
      'all four intro sounds played');
  }

  /** A script returning Function_Stop skips the countdown entirely. */
  static function scriptVetoSkipsCountdown():Void
  {
    Conductor.crochet = 500;

    final state = new PlayState();
    state.scriptsEnabled = true;
    state.scriptHandler = function(event:String) {
      return event == 'onResumeCountdownStart' ? "##PSYCHLUA_FUNCTIONSTOP" : null;
    };

    PlayStateResume.begin(state);

    check(!state.resumeCountdownActive, 'the veto closes the countdown window at once');
    check(!state.paused, 'the veto resumes instantly');
    check(state.resumeTimer == null, 'no timer is left running');
    check(state.resyncVocalsCalls == 1, 'vocals resync through the instant path');
    check(state.scriptLog.indexOf('onResume') >= 0, 'onResume fires for the vetoed resume');
  }

  /** Without the countdown (or the intent) the old instant body runs. */
  static function instantResumeWithoutCountdown():Void
  {
    final state = new PlayState();

    PlayStateResume.finish(state);

    check(!state.paused, 'the instant path unpauses');
    check(state.resyncVocalsCalls == 1, 'vocals resync through the instant path');
    check(state.resetRPCCalls == 1, 'the presence resets through the instant path');
  }

  /** A stray second finish after GO is a no-op. */
  static function finishIsIdempotent():Void
  {
    Conductor.crochet = 500;

    final state = new PlayState();
    PlayStateResume.begin(state);
    state.resumeTimer.simulate(5);
    final resyncs:Int = state.resyncVocalsCalls;
    final onRPCs:Int = state.resetRPCCalls;

    PlayStateResume.finish(state);
    check(state.resyncVocalsCalls == resyncs, 'a stray finish does not resync again');
    check(state.resetRPCCalls == onRPCs, 'a stray finish does not reset the presence again');
  }

  /** Song teardown mid-countdown stops the timer without resuming. */
  static function cancelDropsCountdown():Void
  {
    Conductor.crochet = 500;

    final state = new PlayState();
    PlayStateResume.begin(state);
    check(state.resumeTimer != null, 'the countdown timer exists');

    PlayStateResume.cancel(state);
    check(state.resumeTimer == null, 'cancel drops the timer');
    check(!state.resumeCountdownActive, 'cancel closes the countdown window');
    check(state.scriptVariables.get('resumeCountdownActive') == false, 'scripts are told the countdown stopped');
    check(state.paused, 'cancel never resumes the song on its own');
    check(state.resyncVocalsCalls == 0, 'cancel does not resync vocals');
  }

  /** The FFmpeg/intro paths never reach the countdown; simulate the guard. */
  static function offPreferenceResumesInstantly():Void
  {
    // `shouldRun` is the gate; the spec above pins its truth table. This
    // checks the wiring the gate feeds: a paused state without an intent
    // resumes through the instant body with no countdown side effects.
    final state = new PlayState();
    state.paused = true;

    PlayStateResume.finish(state);

    check(!state.paused, 'the instant body still unpauses');
    check(state.resumeTimer == null, 'no countdown timer is created');
    check(state.createdSprites.length == 0, 'no countdown art is shown');
  }
}
