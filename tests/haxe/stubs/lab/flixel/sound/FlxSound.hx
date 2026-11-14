package flixel.sound;

/** Sound stand-in returned by the `backend.Paths` stub. */
class FlxSound
{
	public var volume:Float = 1;
	public var key:String = null;

	public function new(?key:String)
	{
		this.key = key;
	}
}
