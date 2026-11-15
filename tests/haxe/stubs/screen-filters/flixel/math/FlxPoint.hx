package flixel.math;

/** Only what ChainableEffects needs from FlxPoint in the chainable stub. */
class FlxPoint
{
  public var x:Float;
  public var y:Float;

  public function new(x:Float = 0, y:Float = 0)
  {
    this.x = x;
    this.y = y;
  }

  public function copyFrom(point:FlxPoint):FlxPoint
  {
    x = point.x;
    y = point.y;
    return this;
  }
}
