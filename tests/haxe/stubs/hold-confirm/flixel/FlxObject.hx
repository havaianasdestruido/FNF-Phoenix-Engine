package flixel;

import flixel.math.FlxPoint;

class FlxObject extends FlxBasic
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Float = 0;
  public var height:Float = 0;
  public var alpha:Float = 1;
  public var scrollFactor:FlxPoint = new FlxPoint(1, 1);

  public function new(x:Float = 0, y:Float = 0)
  {
    super();
    this.x = x;
    this.y = y;
  }

  public function setPosition(x:Float = 0, y:Float = 0):Void
  {
    this.x = x;
    this.y = y;
  }

  public function updateHitbox():Void {}
  public function overlapsPoint(point:FlxPoint, inScreenSpace:Bool = false, ?camera:FlxCamera):Bool
  {
    return point.x >= x && point.x < x + width && point.y >= y && point.y < y + height;
  }
}
