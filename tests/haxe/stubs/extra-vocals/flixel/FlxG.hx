package flixel;

import flixel.sound.FlxSound;
import flixel.sound.FlxSoundGroup;

class FlxLogFrontEnd
{
	public var messages:Array<String> = [];

	public function new() {}

	public function add(message:Dynamic):Void
	{
		messages.push(Std.string(message));
	}
}

class FlxSoundFrontEnd
{
	public var list:FlxSoundGroup = new FlxSoundGroup();
	public var music:FlxSound = null;

	public function new() {}
}

class FlxG
{
	public static var sound:FlxSoundFrontEnd = new FlxSoundFrontEnd();
	public static var log:FlxLogFrontEnd = new FlxLogFrontEnd();
}
