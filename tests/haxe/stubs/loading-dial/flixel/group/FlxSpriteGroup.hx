package flixel.group;

import flixel.addons.display.FlxPieDial;
import flixel.math.FlxPoint;

class FlxSpriteGroup
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var scrollFactor:FlxPoint = new FlxPoint();
  public var members:Array<FlxPieDial> = [];

  public function new() {}

  public function add(sprite:FlxPieDial):FlxPieDial
  {
    members.push(sprite);
    sprite.x += x;
    sprite.y += y;
    return sprite;
  }

  public function setPosition(nx:Float, ny:Float):Void
  {
    final dx:Float = nx - x;
    final dy:Float = ny - y;
    x = nx;
    y = ny;
    for (member in members)
    {
      member.x += dx;
      member.y += dy;
    }
  }
}
