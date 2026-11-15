package flixel.text;

import flixel.FlxSprite;
import flixel.util.FlxColor;

enum FlxTextAlign
{
  LEFT;
  CENTER;
  RIGHT;
  JUSTIFY;
}

enum FlxTextBorderStyle
{
  NONE;
  SHADOW;
  OUTLINE;
  OUTLINE_FAST;
}

class FlxText extends FlxSprite
{
  public var text:String;
  public var fieldWidth:Float;
  public var size:Int;
  public var borderSize:Float = 1;
  public var font:String = null;
  public var alignment:FlxTextAlign = LEFT;

  public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, ?text:String = '', size:Int = 8)
  {
    super(x, y);
    this.fieldWidth = fieldWidth;
    this.text = text != null ? text : '';
    this.size = size;
    this.width = fieldWidth;
    this.height = size + 6;
  }

  public function setFormat(?font:String, size:Int = 8, color:FlxColor = 0xFFFFFFFF,
      ?alignment:FlxTextAlign, ?borderStyle:FlxTextBorderStyle, borderColor:FlxColor = 0x00000000):FlxText
  {
    this.font = font;
    this.size = size;
    this.color = color;
    if (alignment != null) this.alignment = alignment;
    this.height = size + 6;
    return this;
  }
}
