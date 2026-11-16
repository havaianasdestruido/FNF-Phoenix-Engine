package flixel;

import flixel.math.FlxPoint;

/**
 * Stand-in for a sprite: a game object, not a DisplayObject (the renderer sees
 * `flashSprite`). Nothing in the filter API touches a sprite — a sprite target
 * is refused — so the stub only carries the fields the stubs and spec read.
 */
class FlxSprite extends FlxBasic
{
  public var graphic:flixel.graphics.FlxGraphic = null;
  public var antialiasing:Bool = true;
  public var scrollFactor:FlxPoint = new FlxPoint(1, 1);
  public var cameras:Array<Dynamic> = null;
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Float = 0;
  public var height:Float = 0;
  public var shader:Dynamic = null;

  public function new(x:Float = 0, y:Float = 0)
  {
    super();
    this.x = x;
    this.y = y;
  }

  public function loadGraphic(Graphic:Dynamic):FlxSprite
    return this;
}
