package flixel;

import flixel.util.FlxColor;

/**
 * Sprite stand-in. As in Flixel, `setGraphicSize` only scales the picture: the
 * hitbox (`width` / `height`) follows on `updateHitbox`, so a layout that
 * forgets the second call is visible to the spec.
 */
class FlxSprite
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Float = 0;
  public var height:Float = 0;
  public var visible:Bool = true;
  public var alpha:Float = 1;
  public var color:FlxColor = FlxColor.WHITE;
  public var antialiasing:Bool = false;

  public var loadedGraphic:String = null;

  var graphicWidth:Float = 0;
  var graphicHeight:Float = 0;

  public function new(x:Float = 0, y:Float = 0)
  {
    this.x = x;
    this.y = y;
  }

  public function loadGraphic(graphic:String):FlxSprite
  {
    loadedGraphic = graphic;
    width = graphicWidth = 1280;
    height = graphicHeight = 720;
    return this;
  }

  public function makeGraphic(width:Int, height:Int, color:FlxColor = FlxColor.WHITE):FlxSprite
  {
    this.color = color;
    this.width = graphicWidth = width;
    this.height = graphicHeight = height;
    return this;
  }

  public function setGraphicSize(width:Float = 0, height:Float = 0):Void
  {
    graphicWidth = width;
    graphicHeight = height;
  }

  public function updateHitbox():Void
  {
    width = graphicWidth;
    height = graphicHeight;
  }

  public function setPosition(x:Float = 0, y:Float = 0):Void
  {
    this.x = x;
    this.y = y;
  }
}
