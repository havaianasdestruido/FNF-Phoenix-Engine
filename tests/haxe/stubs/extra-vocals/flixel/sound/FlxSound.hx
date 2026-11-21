package flixel.sound;

/**
 * Renderer-free FlxSound stand-in: just the surface
 * play.helpers.PlayStateExtraVocals touches.
 */
class FlxSound
{
	public var volume:Float = 1;
	#if FLX_PITCH
	public var pitch:Float = 1;
	#end
	public var time:Float = 0;
	public var length:Float = 0;
	public var playing:Bool = false;
	public var autoDestroy:Bool = false;
	public var loaded:Any = null;
	public var destroyed:Bool = false;
	public var autoRewind:Bool = false;

	public function new() {}

	public function loadEmbedded(sound:Any, ?looped:Bool = false, ?autoDestroy:Bool = false, ?onComplete:Void->Void):FlxSound
	{
		if (sound == null) throw 'cannot load a null sound';
		loaded = sound;
		length = 1000; // pretend every stem is a second long
		return this;
	}

	public function play(?forceRestart:Bool = false, ?startTime:Float = 0, ?endTime:Null<Float>):FlxSound
	{
		playing = true;
		return this;
	}

	public function pause():FlxSound
	{
		playing = false;
		return this;
	}

	public function resume():FlxSound
	{
		playing = true;
		return this;
	}

	public function stop():FlxSound
	{
		playing = false;
		time = 0;
		return this;
	}

	public function destroy():Void
	{
		destroyed = true;
	}
}
