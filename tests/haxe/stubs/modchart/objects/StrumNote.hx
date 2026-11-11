package objects;

import flixel.math.FlxPoint;

class StrumNote
{
	public var x:Float = 0;
	public var y:Float = 0;
	public var angle:Float = 0;
	public var scale:FlxPoint = new FlxPoint(1, 1);
	public var alpha:Float = 1;
	public var noteData:Int = 0;
	public var player:Int = 0;

	public function new() {}
}
