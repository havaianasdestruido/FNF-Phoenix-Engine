package flixel.group;

import flixel.FlxSprite;

class FlxSpriteGroup extends FlxSprite
{
  public var members:Array<FlxSprite> = [];
  public var length(get, never):Int;

  public function new(x:Float = 0, y:Float = 0) super(x, y);

  public function add(sprite:FlxSprite):FlxSprite
  {
    members.push(sprite);
    return sprite;
  }

  inline function get_length():Int return members.length;

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);
    for (member in members) if (member != null) member.update(elapsed);
  }

  override public function destroy():Void
  {
    members = [];
    super.destroy();
  }
}
