import play.helpers.AdaptivePerformance;

/** Deterministic rendered-frame tests; no Flixel, FPS overlay or real clock required. */
class AdaptivePerformanceSpec
{
  static function check(value:Bool, label:String):Void
  {
    if (!value) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    orderedReductionsAndCooldown();
    healthyAndIsolatedStalls();
    interruptionsAndTargetChanges();
    alreadyDisabledAndSongScope();
    invalidSamples();
    Sys.println('AdaptivePerformanceSpec: PASS');
  }

  static function orderedReductionsAndCooldown():Void
  {
    final sim = new AdaptiveSimulation();
    sim.advance(2.8, 30);
    equal(sim.events.length, 0, 'less than three low windows does nothing');
    sim.advance(1.2, 30);
    equal(sim.events.length, 1, 'first sustained slowdown triggers once');
    equal(sim.events[0], AdaptivePerformance.SPLASHES | AdaptivePerformance.COLLECT_GARBAGE,
      'splashes first and GC on the first detection');
    check(sim.policy.splashesDisabled && !sim.policy.ratingsDisabled && !sim.policy.cameraZoomsDisabled,
      'only splashes disabled initially');

    sim.advance(3.5, 30);
    equal(sim.events[1], AdaptivePerformance.RATINGS, 'ratings second without another immediate GC');
    sim.advance(3.5, 30);
    equal(sim.events[2], AdaptivePerformance.CAMERA_ZOOMS, 'camera bops third');
    check(sim.policy.splashesDisabled && sim.policy.ratingsDisabled && sim.policy.cameraZoomsDisabled,
      'all changes stay active');

    sim.advance(10, 30);
    equal(sim.events.length, 4, 'GC is retried only after its cooldown, not every low window');
    equal(sim.events[3], AdaptivePerformance.COLLECT_GARBAGE, 'GC still runs when no cosmetics remain');
    check(sim.eventTimes[3] - sim.eventTimes[0] >= AdaptivePerformance.GC_COOLDOWN_SECONDS,
      'GC requests are at least fifteen seconds apart');
    sim.advance(10, 60);
    equal(sim.events.length, 4, 'a recovered frame rate stops further requests');
    check(sim.policy.splashesDisabled && sim.policy.ratingsDisabled && sim.policy.cameraZoomsDisabled,
      'a recovered frame rate does not restore effects before the next song');
  }

  static function healthyAndIsolatedStalls():Void
  {
    final healthy = new AdaptiveSimulation();
    healthy.advance(15, 60);
    healthy.advance(8, 59.94); // a nominal 60 Hz display with fractional timing
    equal(healthy.events.length, 0, 'sub-FPS pacing differences do not strip cosmetics');

    final slightlyLow = new AdaptiveSimulation();
    slightlyLow.advance(4, 58);
    equal(slightlyLow.events[0], AdaptivePerformance.SPLASHES | AdaptivePerformance.COLLECT_GARBAGE,
      'a sustained drop below target is detected even if it is less than ten percent');

    // A single long hitch counts as one bad window, not as four seconds of
    // continuous bad windows. Healthy windows must break the streak again.
    healthy.jump(4);
    healthy.advance(5, 60);
    equal(healthy.events.length, 0, 'a single multi-second stall does not trigger');

    final intermittent = new AdaptiveSimulation();
    intermittent.advance(1.2, 30);
    intermittent.advance(2, 60);
    intermittent.advance(1.2, 30);
    equal(intermittent.events.length, 0, 'healthy windows reset a low-FPS streak');
    intermittent.advance(3, 30);
    equal(intermittent.events[0], AdaptivePerformance.SPLASHES | AdaptivePerformance.COLLECT_GARBAGE,
      'a later sustained slowdown still triggers');
  }

  static function interruptionsAndTargetChanges():Void
  {
    final sim = new AdaptiveSimulation();
    sim.advance(2.2, 30);
    sim.active = false;
    sim.jump(40); // pause, focus loss, countdown, cutscene or renderer mode
    sim.advance(4, 20);
    equal(sim.events.length, 0, 'inactive frames never trigger');
    sim.active = true;
    sim.advance(2.2, 30);
    equal(sim.events.length, 0, 'resume starts a fresh streak');
    sim.advance(2, 30);
    equal(sim.events.length, 1, 'three fresh low windows after resume trigger');
    sim.policy.resetSamples();
    check(sim.policy.splashesDisabled, 'resetting measurements does not restore effects');

    final target = new AdaptiveSimulation();
    target.advance(2.2, 30); // low against 60
    target.target = 30;
    target.advance(5, 30); // healthy against the new target
    equal(target.events.length, 0, 'target changes reset the old streak and use the new target');
    target.target = 120;
    target.advance(4, 60);
    check(target.events.length == 1, 'high-refresh targets are measured against the actual draw target');
  }

  static function alreadyDisabledAndSongScope():Void
  {
    final skip = new AdaptiveSimulation();
    skip.splashes = false;
    skip.camera = false;
    skip.advance(4, 30);
    equal(skip.events[0], AdaptivePerformance.RATINGS | AdaptivePerformance.COLLECT_GARBAGE,
      'skip an already-disabled splash preference');
    check(skip.policy.splashesDisabled && skip.policy.ratingsDisabled, 'processed overrides persist');
    skip.advance(4, 30);
    check(skip.policy.cameraZoomsDisabled, 'already-disabled camera bops are marked for the song');
    equal(skip.events.length, 1, 'no fake cosmetic notification for an already-disabled option');

    final none = new AdaptiveSimulation();
    none.splashes = none.ratings = none.camera = false;
    none.advance(4, 30);
    equal(none.events[0], AdaptivePerformance.COLLECT_GARBAGE, 'GC runs even when every cosmetic is off');

    final nextSong = new AdaptivePerformance();
    check(!nextSong.splashesDisabled && !nextSong.ratingsDisabled && !nextSong.cameraZoomsDisabled,
      'a new song starts with no adaptive overrides');
  }

  static function invalidSamples():Void
  {
    final sim = new AdaptiveSimulation();
    sim.advance(2.2, 30);
    sim.target = 0;
    sim.advance(4, 30);
    sim.target = 60;
    sim.advance(2.2, 30);
    equal(sim.events.length, 0, 'invalid target discards the partial streak');
    equal(sim.policy.observeFrame(Math.NaN, true, 60, true, true, true), AdaptivePerformance.NONE,
      'invalid timestamp is ignored');
    equal(sim.policy.observeFrame(sim.time, true, Math.POSITIVE_INFINITY, true, true, true), AdaptivePerformance.NONE,
      'invalid infinite target is ignored');

    final clock = new AdaptiveSimulation();
    clock.advance(4, 30);
    clock.policy.resetSamples(); // the adapter does this after a GC request
    clock.time -= 90;
    clock.advance(4, 30);
    equal(clock.events[1], AdaptivePerformance.RATINGS | AdaptivePerformance.COLLECT_GARBAGE,
      'a backwards clock cannot suppress GC until the old time catches up');
  }
}

private class AdaptiveSimulation
{
  public var policy:AdaptivePerformance = new AdaptivePerformance();
  public var time:Float = 100;
  public var target:Float = 60;
  public var active:Bool = true;
  public var splashes:Bool = true;
  public var ratings:Bool = true;
  public var camera:Bool = true;
  public var events:Array<Int> = [];
  public var eventTimes:Array<Float> = [];

  public function new()
  {
    sample();
  }

  public function advance(seconds:Float, fps:Float):Void
  {
    final frames:Int = Std.int(seconds * fps);
    for (_ in 0...frames)
    {
      time += 1.0 / fps;
      sample();
    }
  }

  public function jump(seconds:Float):Void
  {
    time += seconds;
    sample();
  }

  function sample():Void
  {
    final action:Int = policy.observeFrame(time, active, target, splashes, ratings, camera);
    if (action != AdaptivePerformance.NONE)
    {
      events.push(action);
      eventTimes.push(time);
    }
  }
}
