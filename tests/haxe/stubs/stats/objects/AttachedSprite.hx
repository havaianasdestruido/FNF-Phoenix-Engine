package objects;

import flixel.FlxSprite;

class AttachedSprite extends FlxSprite
{
  public var sprTracker:FlxSprite = null;
  public var xAdd:Float = 0;
  public var yAdd:Float = 0;

  public function new(?file:String)
  {
    super();
    if (file != null) loadGraphic(file);
  }
}
