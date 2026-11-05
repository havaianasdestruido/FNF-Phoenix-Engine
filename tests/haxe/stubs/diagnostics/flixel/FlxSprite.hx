package flixel;

import flixel.util.FlxAxes;
import flixel.util.FlxColor;

/** Sprite stand-in: enough state for the page's layout calls to be real. */
class FlxSprite
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Float = 0;
  public var height:Float = 0;
  public var color:FlxColor = 0xFFFFFFFF;
  public var antialiasing:Bool = true;
  public var alpha:Float = 1;
  public var cameras:Array<FlxCamera>;
  public var loadedGraphic:String = null;
  public var madeGraphic:String = null;
  public var graphicSize:String = null;
  public var hitboxUpdates:Int = 0;
  public var centered:Int = 0;

  public function new(x:Float = 0, y:Float = 0) { this.x = x; this.y = y; }
  public function loadGraphic(path:String, ?arg2:Dynamic, ?arg3:Dynamic, ?arg4:Dynamic):FlxSprite
  {
    loadedGraphic = path;
    width = 1280;
    height = 720;
    return this;
  }
  public function makeGraphic(w:Int, h:Int, ?color:Int = 0xFFFFFFFF):Void
  {
    madeGraphic = w + 'x' + h;
    width = w;
    height = h;
  }
  public function setGraphicSize(w:Int, h:Int):Void
  {
    graphicSize = w + 'x' + h;
    width = w;
    height = h;
  }
  public function updateHitbox():Void hitboxUpdates++;
  public function setPosition(newX:Float, newY:Float):Void { x = newX; y = newY; }
  public function screenCenter(?axes:FlxAxes):Void centered++;
}
