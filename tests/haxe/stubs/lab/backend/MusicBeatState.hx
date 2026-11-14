package backend;

import flixel.FlxState;

/** Beat-aware state stand-in (no beat clock needed by the lab). */
class MusicBeatState extends FlxState
{
	public var controls:Controls = new Controls();

	public function new()
	{
		super();
	}
}
