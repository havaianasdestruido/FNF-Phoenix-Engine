package objects;

import flixel.math.FlxPoint;

class Note
{
	public var x:Float = 0;
	public var y:Float = 0;
	public var angle:Float = 0;
	public var scale:FlxPoint = new FlxPoint(1, 1);
	public var alpha:Float = 1;
	public var noteData:Int = 0;
	public var mustPress:Bool = false;
	public var strumTime:Float = 0;
	public var multSpeed:Float = 1;
	public var isSustainNote:Bool = false;
	public var copyX:Bool = true;
	public var copyY:Bool = true;
	public var copyAngle:Bool = true;
	public var copyAlpha:Bool = true;
	public var copyScaleX:Bool = true;
	public var copyScaleY:Bool = true;

	public function new() {}
}
