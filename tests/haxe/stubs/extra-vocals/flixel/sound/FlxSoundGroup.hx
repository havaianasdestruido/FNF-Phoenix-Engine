package flixel.sound;

class FlxSoundGroup
{
	public var members:Array<FlxSound> = [];

	public function new() {}

	public function add(sound:FlxSound):FlxSound
	{
		members.push(sound);
		return sound;
	}

	public function remove(sound:FlxSound):Bool
	{
		return members.remove(sound);
	}
}
