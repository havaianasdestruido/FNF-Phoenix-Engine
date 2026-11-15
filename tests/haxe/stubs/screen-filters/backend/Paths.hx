package backend;

import flixel.graphics.FlxGraphic;

/** Image lookup stub: `specImages` decides what exists. */
class Paths
{
  public static var specImages:Map<String, FlxGraphic> = [];

  public static function image(key:String, ?parentFolder:String = null):FlxGraphic
    return specImages.get(key);
}
