package objects;

import flixel.FlxSprite;

/** Player tag plus the sprite surface the helper measures with. */
class StrumNote extends FlxSprite
{
  public var player:Int = 1;

  public function new(?player:Int = 1)
  {
    super();
    this.player = player;
  }
}
