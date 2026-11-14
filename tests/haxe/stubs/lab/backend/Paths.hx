package backend;

import flixel.sound.FlxSound;

/** Asset lookup stand-in: no files are touched. */
class Paths
{
	public static function font(key:String):String
	{
		return 'fonts/$key';
	}

	public static function sound(key:String):FlxSound
	{
		return new FlxSound('sound:$key');
	}

	public static function music(key:String):FlxSound
	{
		return new FlxSound('music:$key');
	}
}
