import backend.ClientPrefs;
import debug.FrameProfiler;
import flixel.FlxG;
import flixel.tweens.FlxTween;
import openfl.system.System;
import play.PlayState;
import play.PlayState.MockPopup;
import play.PlayState.MockSprite;
import play.helpers.PlayStateAdaptivePerformance;

/** Exercises the actual PlayState adapter against small Flixel/OpenFL doubles. */
@:access(play.helpers.PlayStateAdaptivePerformance)
class AdaptivePerformanceIntegrationSpec
{
  static function check(value:Bool, label:String):Void
  {
    if (!value) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function reset():Void
  {
    ClientPrefs.adaptivePerformance = true;
    ClientPrefs.noteSplashes = true;
    ClientPrefs.ratingPopups = true;
    ClientPrefs.camZooms = true;
    ClientPrefs.enableGC = false;
    ClientPrefs.hideHud = true;
    System.collections = 0;
    System.fail = false;
    FrameProfiler.begins = FrameProfiler.ends = 0;
    FlxTween.cancelled = [];
    FlxG.width = 1280;
    FlxG.height = 720;
    FlxG.drawFramerate = 60;
    FlxG.game._lostFocus = false;
  }

  static function main():Void
  {
    testEffectsAndNotice();
    testInactiveStates();
    testStartsInBackground();
    testNoCosmeticsAndFailedGC();
    #if sys
    Sys.println('AdaptivePerformanceIntegrationSpec: PASS');
    #else
    trace('AdaptivePerformanceIntegrationSpec (browser fallback): PASS');
    #end
  }

  static function testEffectsAndNotice():Void
  {
    reset();
    final sim = new AdapterSimulation();
    final splash = new MockSprite();
    final hold = new MockSprite();
    final rating = new MockPopup(true);
    final olderRating = new MockPopup(true);
    final combo = new MockPopup(false);
    final timing = new MockSprite();
    sim.state.grpNoteSplashes.members.push(splash);
    sim.state.grpHoldSplashes.members.push(hold);
    sim.state.popUpGroup.members = [rating, olderRating, combo];
    sim.state.timingGroup.members.push(timing);

    equal(FlxG.signals.postDraw.listeners.length, 1, 'one draw listener registered');
    sim.advance(4, 30);
    check(sim.adapter.policy.splashesDisabled, 'first slowdown disables splashes');
    equal(splash.kills, 1, 'existing tap splash is retired');
    equal(hold.kills, 1, 'existing sustain splash is retired');
    check(rating.exists && combo.exists && timing.exists, 'rating and combo not changed by first step');
    check(ClientPrefs.noteSplashes && ClientPrefs.ratingPopups && ClientPrefs.camZooms,
      'adaptive overrides do not mutate saved preferences');
    equal(sim.state.songScore, 1234, 'score is untouched');
    equal(sim.state.health, 1.0, 'health is untouched');
    #if sys
    equal(System.collections, 1, 'low FPS requests GC even with automatic GC disabled');
    equal(FrameProfiler.begins, 1, 'explicit GC is profiled');
    equal(FrameProfiler.ends, 1, 'GC profile scope is balanced');
    check(sim.state.added[0].text.indexOf('memory cleanup requested') >= 0, 'GC request is reported');
    #else
    equal(System.collections, 0, 'browser cannot request explicit GC');
    check(sim.state.added[0].text.indexOf('memory cleanup') < 0, 'browser does not claim to collect');
    #end
    equal(sim.state.added.length, 1, 'one reusable notice is created');
    check(sim.state.added[0].visible, 'notice is visible even with Hide HUD enabled');
    check(sim.state.added[0].cameras[0] == sim.state.camOther, 'notice uses the independent overlay camera');
    check(sim.state.added[0].text.indexOf('Note splashes off') >= 0, 'notice identifies the first reduction');
    equal(sim.adapter.noticeTimer.duration, 4.5, 'notice is temporary');
    sim.adapter.noticeTimer.onComplete(sim.adapter.noticeTimer);
    check(!sim.state.added[0].visible, 'notice disappears when its timer completes');

    FlxG.width = 1920;
    FlxG.height = 800;
    sim.adapter.repositionNotice();
    equal(sim.state.added[0].x, 332.0, 'notice follows widescreen layout');
    equal(sim.state.added[0].y, 742.0, 'notice follows resized height');

    sim.advance(4, 30);
    check(sim.adapter.policy.ratingsDisabled, 'continued slowdown disables ratings next');
    check(!rating.exists && !olderRating.exists && !timing.exists, 'all active rating and timing sprites retired');
    check(combo.exists, 'independently enabled combo digits stay visible');
    check(!sim.state.judgeTxt.visible, 'simple rating text is hidden');
    check(FlxTween.cancelled.indexOf(rating) >= 0 && FlxTween.cancelled.indexOf(olderRating) >= 0,
      'rating tweens cannot kill a recycled sprite later');
    check(sim.state.added[0].text.indexOf('Rating popups off') >= 0, 'notice identifies rating reduction');
    check(sim.state.added[0].visible && !sim.adapter.noticeTimer.cancelled, 'later notice is shown and its timer restarted');
    equal(sim.state.added.length, 1, 'notice is reused rather than stacked');

    sim.advance(4, 30);
    check(sim.adapter.policy.cameraZoomsDisabled, 'camera bops are the third reduction');
    check(sim.state.added[0].text.indexOf('Camera bops off') >= 0, 'notice identifies camera reduction');
    check(ClientPrefs.noteSplashes && ClientPrefs.ratingPopups && ClientPrefs.camZooms,
      'preferences still match the player choices after all steps');

    final timer = sim.adapter.noticeTimer;
    sim.adapter.destroy();
    equal(FlxG.signals.postDraw.listeners.length, 0, 'draw listener removed on state destruction');
    check(timer.cancelled, 'notice timer cancelled on destruction');
    sim.adapter.sample(sim.time + 100);
    #if sys
    equal(System.collections, 1, 'destroyed adapter never requests more GC');
    #end
  }

  static function testInactiveStates():Void
  {
    reset();
    final sim = new AdapterSimulation();
    ClientPrefs.adaptivePerformance = false;
    sim.advance(4, 30);
    check(!sim.adapter.policy.splashesDisabled, 'option off does nothing');
    ClientPrefs.adaptivePerformance = true;

    sim.state.startingSong = true;
    sim.advance(4, 30);
    sim.state.startingSong = false;
    sim.state.startedCountdown = false;
    sim.advance(4, 30);
    sim.state.startedCountdown = true;
    sim.state.inCutscene = true;
    sim.advance(4, 30);
    sim.state.inCutscene = false;
    sim.state.ffmpegMode = true;
    sim.advance(4, 30);
    sim.state.ffmpegMode = false;
    sim.state.paused = true;
    sim.advance(4, 30);
    sim.state.paused = false;
    sim.state.subState = {};
    sim.advance(4, 30);
    sim.state.subState = null;
    sim.state.endingSong = true;
    sim.advance(4, 30);
    sim.state.endingSong = false;
    sim.state.finishTimer = {};
    sim.advance(4, 30);
    sim.state.finishTimer = null;
    sim.state.transitioning = true;
    sim.advance(4, 30);
    sim.state.transitioning = false;
    sim.state.isDead = true;
    sim.advance(4, 30);
    sim.state.isDead = false;
    sim.adapter.setFocused(false);
    sim.advance(4, 30);
    sim.adapter.setFocused(true);
    equal(System.collections, 0, 'no GC in inactive modes');
    check(!sim.adapter.policy.splashesDisabled, 'no cosmetics disabled in inactive modes');

    sim.advance(2.2, 30);
    sim.state.paused = true;
    FlxG.signals.postDraw.dispatch(); // exercise the registered draw callback itself
    sim.state.paused = false;
    sim.advance(2.2, 30);
    check(!sim.adapter.policy.splashesDisabled, 'real draw callback discards a paused streak');
    sim.adapter.resetSamples(); // opening/closing a substate even if there are no draws
    sim.time += 50;
    sim.advance(2.2, 30);
    check(!sim.adapter.policy.splashesDisabled, 'pause without draws does not complete an old streak');
    sim.advance(2, 30);
    check(sim.adapter.policy.splashesDisabled, 'monitor resumes after enough live frames');
    sim.adapter.destroy();
  }

  static function testStartsInBackground():Void
  {
    reset();
    FlxG.game._lostFocus = true;
    final sim = new AdapterSimulation();
    sim.advance(4, 30);
    check(!sim.adapter.policy.splashesDisabled && System.collections == 0,
      'a song created after focus loss starts inactive even without a new focus event');
    sim.adapter.setFocused(true);
    sim.advance(4, 30);
    check(sim.adapter.policy.splashesDisabled, 'sampling starts normally on focus gain');
    sim.adapter.destroy();
  }

  static function testNoCosmeticsAndFailedGC():Void
  {
    reset();
    ClientPrefs.noteSplashes = ClientPrefs.ratingPopups = ClientPrefs.camZooms = false;
    final none = new AdapterSimulation();
    none.advance(4, 30);
    check(none.adapter.policy.splashesDisabled && none.adapter.policy.ratingsDisabled && none.adapter.policy.cameraZoomsDisabled,
      'already-disabled preferences are skipped in order');
    #if sys
    equal(System.collections, 1, 'GC still requested with all cosmetics already off');
    check(none.state.added[0].text.indexOf('low FPS') >= 0, 'GC-only slowdown is explained');
    #else
    equal(none.state.added.length, 0, 'no misleading GC-only notice on unsupported targets');
    #end
    none.adapter.destroy();

    reset();
    System.fail = true;
    final failed = new AdapterSimulation();
    failed.advance(4, 30);
    check(failed.adapter.policy.splashesDisabled, 'GC failure cannot prevent a cosmetic reduction');
    #if sys
    equal(FrameProfiler.begins, FrameProfiler.ends, 'failed GC still closes the profile scope');
    check(failed.state.added[0].text.indexOf('memory cleanup') < 0, 'failed GC is not claimed as successful');
    #end
    failed.adapter.destroy();
  }
}

private class AdapterSimulation
{
  public var state:PlayState = new PlayState();
  public var adapter:PlayStateAdaptivePerformance;
  public var time:Float = 100;

  public function new()
  {
    FlxG.state = state;
    adapter = new PlayStateAdaptivePerformance(state);
    state.adaptivePerformance = adapter;
    @:privateAccess adapter.sample(time);
  }

  public function advance(seconds:Float, fps:Int):Void
  {
    for (_ in 0...Std.int(seconds * fps))
    {
      time += 1.0 / fps;
      @:privateAccess adapter.sample(time);
    }
  }
}
