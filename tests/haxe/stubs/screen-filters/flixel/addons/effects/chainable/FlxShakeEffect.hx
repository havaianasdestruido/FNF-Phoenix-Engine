package flixel.addons.effects.chainable;

import flixel.util.FlxAxes;

/** Records the arguments `ChainableEffects.shake()` resolves. */
class FlxShakeEffect extends RecordedEffect
{
  public var intensity:Float = 0;
  public var duration:Float = 0;
  public var completed:Void->Void;
  public var axes:FlxAxes = FlxAxes.XY;

  public function new(Intensity:Float = 5, Duration:Float = 0.5, ?OnComplete:Void->Void, ?Axes:FlxAxes)
  {
    super();
    intensity = Intensity;
    duration = Duration;
    completed = OnComplete;
    axes = Axes;
  }

  public function start(Force:Bool = false):Void {}

  public function reset(Intensity:Float = 5, Duration:Float = 0.5, ?OnComplete:Void->Void, ?Axes:FlxAxes):Void
  {
    // The real addon substitutes XY for null here; that is the only reason
    // `start()` works without an axes argument.
    if (Axes == null) Axes = FlxAxes.XY;
    intensity = Intensity;
    duration = Duration;
    completed = OnComplete;
    axes = Axes;
  }
}
