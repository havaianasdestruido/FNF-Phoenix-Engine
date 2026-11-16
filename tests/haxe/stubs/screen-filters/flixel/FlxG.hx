package flixel;

import openfl.display.Sprite;

/** The two globals `ScreenFilters` reads: the game object and the RNG-free state. */
class FlxG
{
  /** Stand-in for the real FlxGame, which is a DisplayObject with `filters`. */
  public static var game:Sprite = new Sprite();
}
