package flixel.text;

import flixel.FlxSprite;

enum FlxTextAlign { LEFT; CENTER; RIGHT; JUSTIFY; }
enum FlxTextBorderStyle { NONE; SHADOW; OUTLINE; OUTLINE_FAST; }

class FlxText extends FlxSprite
{
  public var text:String = '';
  public var fieldWidth:Float = 0;
  public var borderSize:Float = 1;
  public var alignment:FlxTextAlign = LEFT;

  public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, text:String = '', size:Int = 8)
  {
    super(x, y);
    this.fieldWidth = fieldWidth;
    this.text = text;
    width = fieldWidth;
  }

  public function setFormat(?font:String, size:Int = 8, color:Int = 0xFFFFFFFF,
      ?alignment:FlxTextAlign, ?borderStyle:FlxTextBorderStyle, borderColor:Int = 0):FlxText
  {
    if (alignment != null) this.alignment = alignment;
    return this;
  }
}
