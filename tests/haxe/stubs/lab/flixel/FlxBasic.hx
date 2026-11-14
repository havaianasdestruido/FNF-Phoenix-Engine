package flixel;

/** Minimal object base so `FlxState.add` can stay generic like the real one. */
class FlxBasic
{
	public var exists:Bool = true;
	public var visible:Bool = true;

	public function new()
	{
	}

	public function update(elapsed:Float):Void
	{
	}

	public function destroy():Void
	{
	}
}
