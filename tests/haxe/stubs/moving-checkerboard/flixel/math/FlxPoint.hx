package flixel.math;

class FlxPoint
{
  public var x:Float = 0;
  public var y:Float = 0;

  public function new() {}

  public function set(x:Float = 0, y:Float = 0):FlxPoint
  {
    this.x = x;
    this.y = y;
    return this;
  }
}
