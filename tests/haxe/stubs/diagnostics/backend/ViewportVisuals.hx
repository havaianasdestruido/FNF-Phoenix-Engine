package backend;

import flixel.FlxSprite;

class ViewportVisuals
{
  public static var covers:Int = 0;

  public static function cover(sprite:FlxSprite, ?scale:Float = 1.0):Void
    covers++;
}
