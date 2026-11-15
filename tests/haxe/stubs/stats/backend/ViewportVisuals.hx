package backend;

import flixel.FlxG;
import flixel.FlxSprite;

class ViewportVisuals
{
  public static var coverCalls:Int = 0;
  public static var fillCalls:Int = 0;

  public static function cover(sprite:FlxSprite, overscan:Float = 1.0):Void
  {
    coverCalls++;
    if (sprite != null)
    {
      sprite.setGraphicSize(FlxG.width * overscan, FlxG.height * overscan);
      sprite.updateHitbox();
    }
  }

  public static function fill(sprite:FlxSprite):Void
  {
    fillCalls++;
    if (sprite != null)
    {
      sprite.setGraphicSize(FlxG.width, FlxG.height);
      sprite.updateHitbox();
    }
  }

  public static function reset():Void
  {
    coverCalls = 0;
    fillCalls = 0;
  }
}
