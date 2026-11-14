package flixel;

import flixel.math.FlxPoint;
import flixel.util.FlxColor;

class FlxSprite extends FlxObject
{
  public var color:FlxColor = 0xFFFFFFFF;
  public var alpha:Float = 1;
  public var antialiasing:Bool = true;
  public var scale:FlxPoint = new FlxPoint(1, 1);
  public var loadedGraphic:String = null;
  public var madeColor:Int = 0;
  public var graphicSizeW:Float = 0;
  public var graphicSizeH:Float = 0;
  public var hitboxUpdates:Int = 0;

  public function new(x:Float = 0, y:Float = 0)
  {
    super(x, y);
  }

  public function loadGraphic(graphic:Dynamic, animated:Bool = false, frameWidth:Int = 0, frameHeight:Int = 0):FlxSprite
  {
    loadedGraphic = Std.string(graphic);
    width = frameWidth > 0 ? frameWidth : 1280;
    height = frameHeight > 0 ? frameHeight : 720;
    return this;
  }

  public function makeGraphic(w:Int, h:Int, color:Int = 0xFFFFFFFF, unique:Bool = false, ?key:String):FlxSprite
  {
    madeColor = color;
    width = w;
    height = h;
    return this;
  }

  public function setGraphicSize(w:Float = 0, h:Float = 0):Void
  {
    graphicSizeW = w;
    graphicSizeH = h;
    if (w > 0) width = w;
    if (h > 0) height = h;
  }

  public function updateHitbox():Void
  {
    hitboxUpdates++;
  }

  public function getGraphicMidpoint(?point:FlxPoint):FlxPoint
    return getMidpoint(point);
}
