package flixel;

import flixel.util.FlxSignal;

/**
 * Stand-in for the two `FlxG` surfaces `shaders.EffectTicker` reads: the frame
 * delta and the current state, plus the `postUpdate`/`preStateSwitch` signals it
 * attaches to. `dispatch()` is public on the real signals too, which is what lets
 * the spec drive a frame or a state switch by hand.
 */
class FlxG
{
  public static var elapsed:Float = 0.0;

  /** The real field is `FlxState`; the ticker only compares it for identity. */
  public static var state:Dynamic = null;

  public static var signals:StubSignals = new StubSignals();
}

class StubSignals
{
  public var postUpdate:FlxSignal = new FlxSignal();
  public var preStateSwitch:FlxSignal = new FlxSignal();

  public function new() {}
}
