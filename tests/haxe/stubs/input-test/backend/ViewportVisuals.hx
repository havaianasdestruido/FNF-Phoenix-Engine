package backend;

import flixel.FlxSprite;

class ViewportVisuals
{
  /** Spec output: how often a background was fitted to the viewport. */
  public static var covers:Int = 0;

  public static function cover(sprite:FlxSprite, scale:Float = 1.0):Void
    covers++;
}
