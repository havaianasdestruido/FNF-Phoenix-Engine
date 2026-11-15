package flixel.graphics;

import openfl.display.BitmapData;

/** Only the `bitmap` field `ScreenFilters.loadMapBitmap` reads. */
class FlxGraphic
{
  public var bitmap:BitmapData;

  public function new(?bitmap:BitmapData)
  {
    this.bitmap = bitmap;
  }
}
