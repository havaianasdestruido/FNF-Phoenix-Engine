package flixel;

import flixel.math.FlxPoint;

class FlxSprite extends FlxObject
{
  public var scale:FlxPoint = new FlxPoint(1, 1);
  public var origin(default, null):FlxPoint = new FlxPoint();
  public var frameWidth:Int = 1;
  public var frameHeight:Int = 1;

  public function new(x:Float = 0, y:Float = 0) super(x, y);

  public function makeGraphic(width:Int, height:Int, color:Int = 0xFFFFFFFF):FlxSprite
  {
    frameWidth = width;
    frameHeight = height;
    this.width = width;
    this.height = height;
    return this;
  }

  override public function updateHitbox():Void
  {
    width = Math.abs(scale.x) * frameWidth;
    height = Math.abs(scale.y) * frameHeight;
  }
}
