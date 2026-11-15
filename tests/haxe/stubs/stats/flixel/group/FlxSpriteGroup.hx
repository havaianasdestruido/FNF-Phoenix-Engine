package flixel.group;

import flixel.FlxSprite;

class FlxSpriteGroup extends FlxSprite
{
  public var members:Array<FlxSprite> = [];
  public var length(get, never):Int;

  public function new(x:Float = 0, y:Float = 0)
  {
    super(x, y);
  }

  function get_length():Int
    return members.length;

  public function add(sprite:FlxSprite):FlxSprite
  {
    members.push(sprite);
    return sprite;
  }

  public function forEach(fn:FlxSprite->Void):Void
  {
    for (member in members)
      if (member != null) fn(member);
  }
}
