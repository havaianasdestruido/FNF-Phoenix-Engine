package flixel;
import flixel.util.FlxAxes;
class FlxCamera
{
	public var calls:Int = 0;
	public var intensity:Float = 0;
	public var duration:Float = 0;
	public var callback:Void->Void;
	public var force:Bool;
	public var axes:FlxAxes;
	public function new() {}
	public function shake(Intensity:Float = 0.05, Duration:Float = 0.5,
		?OnComplete:Void->Void, Force:Bool = true, ?Axes:FlxAxes):Void
	{
		calls++;
		intensity = Intensity;
		duration = Duration;
		callback = OnComplete;
		force = Force;
		axes = Axes;
	}
}
