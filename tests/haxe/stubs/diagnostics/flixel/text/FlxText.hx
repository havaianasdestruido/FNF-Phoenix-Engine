package flixel.text;

import flixel.FlxSprite;

/** The text block the page renders; height comes from the line count it is given. */
class FlxText extends FlxSprite
{
  public var fieldWidth:Int = 0;
  public var wordWrap:Bool = false;
  public var borderSize:Float = 0;
  public var format:String = null;
  public var textValue:String = '';

  public var text(get, set):String;
  function get_text():String return textValue;
  function set_text(value:String):String { textValue = value; recalc(); return value; }

  public function new(x:Float = 0, y:Float = 0, FieldWidth = 0, ?Text:String, ?Size:Int = 16)
  {
    super(x, y);
    fieldWidth = FieldWidth;
    if (Text != null) textValue = Text;
    if (Size != null) height = Std.int((textValue.length == 0 ? 1 : textValue.split('\n').length) * Size);
  }

  function recalc():Void
  {
    final size:Int = (format == null) ? 16 : Std.parseInt(format);
    height = Std.int((textValue.length == 0 ? 1 : textValue.split('\n').length) * (size == null ? 16 : size));
    width = fieldWidth;
  }

  public function setFormat(?Font:String, ?Size:Dynamic, ?Color:Dynamic, ?Align:Dynamic,
      ?BorderStyle:FlxTextBorderStyle, ?BorderColor:Dynamic, ?BorderSize:Float):FlxText
  {
    format = Std.string(Size);
    return this;
  }
}

enum abstract FlxTextBorderStyle(String) from String to String
{
  var NONE = 'NONE';
  var OUTLINE = 'OUTLINE';
  var SHADOW = 'SHADOW';
}

enum abstract FlxTextAlign(Int) from Int to Int
{
  var LEFT = 0;
  var CENTER = 1;
  var RIGHT = 2;
}
