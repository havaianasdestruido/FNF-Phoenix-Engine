package flixel;

/** State stand-in with the `add`/`remove`/lifecycle surface editors use. */
class FlxState
{
	public var members:Array<FlxBasic> = [];

	public function new()
	{
	}

	public function create():Void
	{
	}

	public function add<T:FlxBasic>(object:T):T
	{
		members.push(object);
		return object;
	}

	public function remove<T:FlxBasic>(object:T, splice:Bool = false):T
	{
		members.remove(object);
		return object;
	}

	public function update(elapsed:Float):Void
	{
	}

	public function destroy():Void
	{
	}
}
