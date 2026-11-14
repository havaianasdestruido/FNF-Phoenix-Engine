package flixel;

import flixel.math.FlxPoint;
import flixel.util.FlxAxes;

class FlxObject extends FlxBasic
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Float = 0;
  public var height:Float = 0;
  public var scrollFactor:FlxPoint = new FlxPoint(1, 1);

  public function new(x:Float = 0, y:Float = 0, width:Float = 0, height:Float = 0)
  {
    super();
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  public function setPosition(newX:Float = 0, newY:Float = 0):Void
  {
    x = newX;
    y = newY;
  }

  public function getMidpoint(?point:FlxPoint):FlxPoint
    return new FlxPoint(x + width * 0.5, y + height * 0.5);

  public function screenCenter(axes:FlxAxes = XY):FlxObject
  {
    if (axes == X || axes == XY) x = (FlxG.width - width) * 0.5;
    if (axes == Y || axes == XY) y = (FlxG.height - height) * 0.5;
    return this;
  }
}
