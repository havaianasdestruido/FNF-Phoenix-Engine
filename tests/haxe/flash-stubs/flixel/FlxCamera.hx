package flixel;
import flixel.util.FlxColor;
class FlxCamera {
	public var calls:Int = 0;
	public var color:FlxColor;
	public var duration:Float;
	public var force:Bool;
	public var callback:Void->Void;
	public function new() {}
	public function flash(color:FlxColor, duration:Float, ?callback:Void->Void, force:Bool = false):Void {
		calls++;
		this.color = color;
		this.duration = duration;
		this.callback = callback;
		this.force = force;
	}
}
