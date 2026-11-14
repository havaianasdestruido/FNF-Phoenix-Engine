package flixel;

import flixel.math.FlxPoint;
import flixel.util.FlxColor;

/** Sprite stand-in that records the calls the lab makes on it. */
class FlxSprite extends FlxBasic
{
	public var x:Float = 0;
	public var y:Float = 0;
	public var width:Float = 0;
	public var height:Float = 0;
	public var alpha:Float = 1;
	public var angle:Float = 0;
	public var color:FlxColor = 0xFFFFFFFF;
	public var scale:FlxPoint = new FlxPoint(1, 1);
	public var scrollFactor:FlxPoint = new FlxPoint(1, 1);
	public var madeGraphic:String = null;

	public function new(?x:Float = 0, ?y:Float = 0)
	{
		super();
		this.x = x;
		this.y = y;
	}

	public function makeGraphic(width:Int, height:Int, ?color:FlxColor = FlxColor.WHITE):FlxSprite
	{
		this.width = width;
		this.height = height;
		madeGraphic = width + 'x' + height;
		return this;
	}

	public function setGraphicSize(width:Int, ?height:Int = 0):Void
	{
		this.width = width;
		if (height != 0)
			this.height = height;
	}

	public function setPosition(x:Float, y:Float):Void
	{
		this.x = x;
		this.y = y;
	}
}
