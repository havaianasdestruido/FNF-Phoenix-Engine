package flixel;

import openfl.display.BitmapData;

/**
 * Minimal FlxSprite stand-in: just the frame surface CoolUtil.dominantColor
 * walks, plus the useFramePixels toggle it flips on and off.
 */
class FlxSprite
{
  public var useFramePixels:Bool = false;
  public var frameWidth:Int = 0;
  public var frameHeight:Int = 0;
  public var framePixels:BitmapData;

  public function new() {}
}
