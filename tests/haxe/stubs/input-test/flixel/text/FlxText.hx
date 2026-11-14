package flixel.text;

import flixel.FlxSprite;
import flixel.util.FlxColor;

/**
 * Text stand-in: the height is the line count times the font size, which is
 * enough for the page's bottom-anchored layout to be real arithmetic, and
 * `textSets` counts assignments so the spec can tell a rebuild from an idle frame.
 */
class FlxText extends FlxSprite
{
  public var fieldWidth(default, set):Float = 0;
  public var borderSize:Float = 0;
  public var size:Int = 8;
  public var font:String = null;
  public var alignment:FlxTextAlign = LEFT;
  public var textSets:Int = 0;

  public var text(default, set):String = '';

  public function new(x:Float = 0, y:Float = 0, fieldWidth:Float = 0, ?text:String, size:Int = 8)
  {
    super(x, y);
    this.size = size;
    this.fieldWidth = fieldWidth;
    if (text != null) this.text = text;
    textSets = 0;
    measure();
  }

  public function setFormat(?font:String, size:Int = 8, color:FlxColor = FlxColor.WHITE, ?alignment:FlxTextAlign, ?borderStyle:FlxTextBorderStyle,
      borderColor:FlxColor = FlxColor.BLACK):FlxText
  {
    this.font = font;
    this.size = size;
    this.color = color;
    if (alignment != null) this.alignment = alignment;
    measure();
    return this;
  }

  function set_text(value:String):String
  {
    text = value;
    textSets++;
    measure();
    return value;
  }

  function set_fieldWidth(value:Float):Float
  {
    fieldWidth = value;
    measure();
    return value;
  }

  function measure():Void
  {
    width = fieldWidth;
    height = (text == null || text.length == 0 ? 1 : text.split('\n').length) * size;
  }
}

enum abstract FlxTextBorderStyle(Int)
{
  var NONE = 0;
  var SHADOW = 1;
  var OUTLINE = 2;
  var OUTLINE_FAST = 3;
}

enum abstract FlxTextAlign(String) from String
{
  var LEFT = 'left';
  var CENTER = 'center';
  var RIGHT = 'right';
  var JUSTIFY = 'justify';
}
