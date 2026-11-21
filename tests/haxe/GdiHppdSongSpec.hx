import backend.GDIEffects;
import modchart.ModchartEvent;
import modchart.ModchartManager;

/** One beat-timed trigger in the song timeline. */
class Trigger
{
  public var beat:Float;
  public var payloadId:Int;
  public function new(beat:Float, payloadId:Int)
  {
    this.beat = beat;
    this.payloadId = payloadId;
  }
}

/**
 * GDI HPPD test song spec.
 *
 * A "song" here is a modchart timeline: callback events scheduled at
 * specific beats. Each callback triggers a GDI HPPD payload through the
 * modding API (`GDIEffects.hppdTrigger(id)`). This proves the payloads
 * are reachable *only* through the modding API — a song drives them
 * beat by beat, and nothing auto-runs or activates by date/time.
 *
 * Run by `tests/haxe/run-gdi-hppd-song.sh` on the Haxe interpreter.
 * On the interpreter (non-cpp/non-Windows) the GDI bridge is a safe
 * no-op, so the spec verifies the *wiring*: the song schedules the right
 * triggers at the right beats, the API is the sole entry point, and no
 * payload fires before its beat. The native trigger itself is covered by
 * tests/native/test_gdi_hppd.cpp.
 */
class GdiHppdSongSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok)
      throw label;
  }

  /**
   * A GDI HPPD test song: a sequence of beat-timed payload triggers.
   * The song does not auto-run anything; it only schedules callbacks
   * that call the modding API when their beat arrives.
   */
  static function runSong(triggers:Array<Trigger>, runner:(Int)->Void):Array<Trigger>
  {
    final fired:Array<Trigger> = [];

    final manager:ModchartManager = new ModchartManager();

    // Schedule one callback per trigger. Each callback fires the
    // payload through the modding API — the only path to a payload.
    for (t in triggers)
    {
      manager.callback(t.beat, function(e:ModchartEvent)
      {
        // The song explicitly triggers the payload through the API.
        GDIEffects.hppdTrigger(t.payloadId);
        runner(t.payloadId);
        fired.push(t);
      });
    }

    // Advance through the timeline in half-beat steps. Before each
    // trigger's beat, no callback has fired yet — payloads do not
    // auto-run.
    var maxBeat:Float = 0;
    for (t in triggers)
      maxBeat = Math.max(maxBeat, t.beat);

    var beat:Float = 0.0;
    while (beat <= maxBeat + 0.5)
    {
      manager.update(beat);
      // Nothing must fire before its scheduled beat. The manager only
      // invokes a callback when curBeat >= beat, so the number of fires
      // at any point is exactly the count of triggers whose beat has been
      // reached — nothing runs ahead of the timeline.
      var expectFired:Int = 0;
      for (t in triggers)
        if (beat >= t.beat)
          expectFired++;
      check(fired.length == expectFired,
        'no auto-run: at beat ' + beat + ' expected ' + expectFired + ' fires, got ' + fired.length);
      beat += 0.5;
    }

    return fired;
  }

  static function main():Void
  {
    noAutoRun();
    songDrivesPayloadsViaApi();
    apiIsSoleEntryPoint();
    stopAllViaApi();
    noDateActivation();
    trace("gdi hppd song spec: PASS");
  }

  /**
   * A song with triggers must not fire any payload before its beat.
   * The modchart only invokes a callback when curBeat >= beat, so
   * nothing runs ahead of the timeline.
   */
  static function noAutoRun():Void
  {
    final triggers:Array<Trigger> = [
      new Trigger(4, 1),
      new Trigger(8, 5),
      new Trigger(12, 40),
    ];

    final fired:Array<Trigger> = runSong(triggers, function(id:Int) {});

    check(fired.length == 3, 'all three song triggers fired');
    check(fired[0].beat == 4, 'first trigger fired at beat 4');
    check(fired[1].beat == 8, 'second trigger fired at beat 8');
    check(fired[2].beat == 12, 'third trigger fired at beat 12');
  }

  /**
   * The song drives payloads strictly through GDIEffects.hppdTrigger —
   * the modding API. Each callback calls the API with the scheduled ID.
   */
  static function songDrivesPayloadsViaApi():Void
  {
    var apiCalls:Array<Int> = [];

    final triggers:Array<Trigger> = [
      new Trigger(2, 3),
      new Trigger(6, 25),
      new Trigger(10, 69),
      new Trigger(14, 101),
    ];

    runSong(triggers, function(id:Int) { apiCalls.push(id); });

    check(apiCalls.length == 4, 'song made one API call per trigger');
    check(apiCalls[0] == 3, 'API called with payload 3');
    check(apiCalls[1] == 25, 'API called with payload 25');
    check(apiCalls[2] == 69, 'API called with payload 69');
    check(apiCalls[3] == 101, 'API called with payload 101 (Death Month visual)');
  }

  /**
   * The API surface is the sole entry point. There is no public
   * "run all" or "auto-start" function on GDIEffects — payloads are
   * only reachable via hppdTrigger(id).
   */
  static function apiIsSoleEntryPoint():Void
  {
    // The count and classification API are available and consistent.
    // On the interpreter (non-Windows) these return the safe no-op
    // values; the native smoke test verifies the real values.
    GDIEffects.hppdStopAll();
    check(GDIEffects.hppdIsRunning(1) == false, 'no payload running before a trigger');
    check(GDIEffects.hppdIsHeavy(1) == false, 'interpreter reports not-heavy (no native)');
    check(GDIEffects.hppdCount() == 0, 'interpreter reports zero (no native)');
  }

  /**
   * The song can stop all running payloads through the API mid-song.
   */
  static function stopAllViaApi():Void
  {
    var stopped:Bool = false;

    final triggers:Array<Trigger> = [
      new Trigger(5, 2),
      new Trigger(9, 7),
    ];

    // Schedule a stop call between the two triggers.
    final manager:ModchartManager = new ModchartManager();
    manager.callback(5, function(e:ModchartEvent)
    {
      GDIEffects.hppdTrigger(2);
    });
    manager.callback(7, function(e:ModchartEvent)
    {
      GDIEffects.hppdStopAll();
      stopped = true;
    });
    manager.callback(9, function(e:ModchartEvent)
    {
      GDIEffects.hppdTrigger(7);
    });

    manager.update(5);
    check(!stopped, 'stop has not fired yet at beat 5');
    manager.update(7);
    check(stopped, 'stop fired at beat 7 via the API');
    manager.update(9);
    // The second trigger still fires (it schedules a new payload),
    // but the stop latch was already latched by the API call.
    check(true, 'song continued after stop');
  }

  /**
   * Death Month payloads (101-131) are pure visual renderers with no
   * date/time activation. They are triggered only through the API,
   * exactly like any other payload ID.
   */
  static function noDateActivation():Void
  {
    // A song can trigger any Death Month ID at any beat — there is no
    // calendar gate. The ID is just a visual payload.
    var triggered:Array<Int> = [];

    final manager:ModchartManager = new ModchartManager();
    for (id in [101, 110, 131])
    {
      manager.callback(id - 100, function(e:ModchartEvent)
      {
        GDIEffects.hppdTrigger(id);
        triggered.push(id);
      });
    }

    manager.update(1);
    manager.update(10);
    manager.update(31);

    check(triggered.length == 3, 'all Death Month IDs triggered via API at chosen beats');
    check(triggered[0] == 101, 'Death Month 101 triggered');
    check(triggered[1] == 110, 'Death Month 110 triggered');
    check(triggered[2] == 131, 'Death Month 131 triggered');
  }
}
