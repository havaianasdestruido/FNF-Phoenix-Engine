package flixel.util;

/**
 * Deterministic timer stub: `start()` registers on the global manager like the
 * real one, and `simulate(n)` fires the loop n times by hand so the spec can
 * walk the countdown tick by tick.
 */
class FlxTimer
{
  public var time:Float = 0;
  public var loops:Int = 1;
  public var active:Bool = false;
  public var finished:Bool = true;
  public var onComplete:Null<FlxTimer->Void> = null;
  var fired:Int = 0;

  public static var globalManager:FlxTimerManager = new FlxTimerManager();

  public function new() {}

  public function start(time:Float, ?onComplete:FlxTimer->Void, loops:Int = 1):FlxTimer
  {
    this.time = Math.abs(time);
    this.loops = loops;
    this.onComplete = onComplete;
    fired = 0;
    active = true;
    finished = false;
    globalManager.add(this);
    return this;
  }

  public function cancel():Void
  {
    finished = true;
    active = false;
  }

  /** Fires the loop up to `count` times, stopping as soon as the timer finishes. */
  public function simulate(count:Int):Void
  {
    for (i in 0...count)
    {
      if (finished) return;
      fired++;
      if (loops > 0 && fired >= loops) finished = true;
      final fn = onComplete;
      if (fn != null) fn(this);
    }
  }
}

class FlxTimerManager
{
  public var timers:Array<FlxTimer> = [];

  public function new() {}

  public function add(timer:FlxTimer):Void
  {
    timers.push(timer);
  }

  public function forEach(fn:FlxTimer->Void):Void
  {
    for (timer in timers) fn(timer);
  }
}
