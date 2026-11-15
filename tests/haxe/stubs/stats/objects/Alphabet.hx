package objects;

import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;

class Alphabet extends FlxSpriteGroup
{
  public var text:String;
  public var letters:Array<FlxSprite> = [];

  public function new(x:Float = 0, y:Float = 0, text:String = '', bold:Bool = true)
  {
    super(x, y);
    this.text = text;
    width = text.length * 24;
    height = 64;
    letters.push(new FlxSprite());
  }
}
