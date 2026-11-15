package flixel.ui;

import flixel.FlxSprite;

enum FlxBarFillDirection
{
  LEFT_TO_RIGHT;
  RIGHT_TO_LEFT;
  TOP_TO_BOTTOM;
  BOTTOM_TO_TOP;
}

class FlxBar extends FlxSprite
{
  public var value:Float = 0;

  public function new(x:Float = 0, y:Float = 0, ?direction:FlxBarFillDirection,
      width:Int = 100, height:Int = 10, ?parentRef:Dynamic, variable:String = '',
      min:Float = 0, max:Float = 100, showBorder:Bool = false)
  {
    super(x, y);
    this.width = width;
    this.height = height;
  }

  public function createFilledBar(empty:Int, fill:Int, showBorder:Bool = false, border:Int = 0xFFFFFFFF):FlxBar
    return this;

  public function setRange(min:Float, max:Float):Void {}
}
