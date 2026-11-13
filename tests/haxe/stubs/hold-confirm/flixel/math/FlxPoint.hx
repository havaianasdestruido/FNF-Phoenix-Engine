package flixel.math;

class FlxPoint
{
  public var x:Float;
  public var y:Float;

  public function new(x:Float = 0, y:Float = 0) { this.x = x; this.y = y; }

  public function set(x:Float = 0, y:Float = 0):FlxPoint
  {
    this.x = x;
    this.y = y;
    return this;
  }

  public function copyFrom(point:FlxPoint):FlxPoint return set(point.x, point.y);
}
