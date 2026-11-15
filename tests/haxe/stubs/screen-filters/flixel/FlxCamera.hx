package flixel;

import openfl.filters.BitmapFilter;

/**
 * Only the filter surface `ScreenFilters` touches, declared exactly like the
 * real `FlxCamera`: a `Null<Array<BitmapFilter>>` that `FlxCamera.render()`
 * pushes into `flashSprite.filters` every frame, and a `filtersEnabled` switch.
 */
class FlxCamera extends FlxBasic
{
  public var filters:Null<Array<BitmapFilter>> = null;
  public var filtersEnabled:Bool = true;

  public function new()
  {
    super();
  }
}
