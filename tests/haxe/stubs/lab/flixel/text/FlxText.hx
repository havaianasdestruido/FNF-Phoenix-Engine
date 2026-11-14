package flixel.text;

import flixel.FlxSprite;

/** Alignment values, mirrored from `FlxText.FlxTextAlign`. */
enum abstract FlxTextAlign(String) from String to String
{
	var LEFT = 'left';
	var CENTER = 'center';
	var RIGHT = 'right';
}

/** Border styles, mirrored from `FlxText.FlxTextBorderStyle`. */
enum abstract FlxTextBorderStyle(Int) from Int to Int
{
	var NONE = 0;
	var OUTLINE = 1;
	var OUTLINE_FAST = 2;
}

/** Text stand-in: remembers the string and the alignment it was given. */
class FlxText extends FlxSprite
{
	public var text:String = '';
	public var wordWrap:Bool = true;
	public var align:FlxTextAlign = FlxTextAlign.LEFT;
	public var font:String = null;
	public var size:Int = 16;

	public function new(x:Float = 0, y:Float = 0, width:Int = 0, text:String = '', size:Int = 16)
	{
		super(x, y);
		this.width = width;
		this.text = text;
		this.size = size;
	}

	public function setFormat(?font:String, ?size:Int, ?color:FlxColor, ?align:FlxTextAlign, ?borderStyle:FlxTextBorderStyle,
		?borderColor:FlxColor, ?borderSize:Float):FlxText
	{
		this.font = font;
		if (size != null)
			this.size = size;
		if (align != null)
			this.align = align;
		return this;
	}
}
