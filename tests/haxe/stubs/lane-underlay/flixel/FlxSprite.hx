package flixel;

import flixel.math.FlxPoint;

/**
 * The `FlxSprite` surface the overlay touches. `setGraphicSize` only writes the
 * scale (like the real one); `updateHitbox` bakes it into `width`/`height`, so
 * the stub reproduces the two-step sizing the helper relies on.
 */
class FlxSprite extends FlxBasic
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Float = 0;
  public var height:Float = 0;
  public var alpha:Float = 1.0;
  public var scale:FlxPoint = new FlxPoint(1, 1);
  public var offset:FlxPoint = new FlxPoint();
  public var scrollFactor:FlxPoint = new FlxPoint(1, 1);
  public var cameras:Array<FlxCamera> = null;

  /** 1x1 pixel stand-in for the generated graphic. */
  public var frameWidth:Int = 1;
  public var frameHeight:Int = 1;
  public var graphicColor:Int = 0;

  public function new(?x:Float = 0, ?y:Float = 0)
  {
    super();
    this.x = x;
    this.y = y;
  }

  public function makeGraphic(graphicWidth:Int, graphicHeight:Int, color:Int, unique:Bool = false):FlxSprite
  {
    frameWidth = graphicWidth;
    frameHeight = graphicHeight;
    width = graphicWidth;
    height = graphicHeight;
    graphicColor = color;
    return this;
  }

  public function setPosition(newX:Float, newY:Float):FlxSprite
  {
    x = newX;
    y = newY;
    return this;
  }

  public function setGraphicSize(newWidth:Float = 0, newHeight:Float = 0):Void
  {
    if (newWidth <= 0 && newHeight <= 0) return;
    scale.set(newWidth / frameWidth, newHeight / frameHeight);
    if (newWidth <= 0) scale.x = scale.y;
    else if (newHeight <= 0) scale.y = scale.x;
  }

  public function updateHitbox():Void
  {
    this.width = Math.abs(scale.x) * frameWidth;
    this.height = Math.abs(scale.y) * frameHeight;
  }
}
