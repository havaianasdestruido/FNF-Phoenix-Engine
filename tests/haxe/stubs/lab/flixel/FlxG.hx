package flixel;

import flixel.sound.FlxSound;

/** Keyboard map: every key the lab reads, as real Booleans the spec can drive. */
class FlxKeyMap
{
	public var UP:Bool = false;
	public var DOWN:Bool = false;
	public var LEFT:Bool = false;
	public var RIGHT:Bool = false;
	public var SPACE:Bool = false;
	public var SHIFT:Bool = false;
	public var CONTROL:Bool = false;
	public var TAB:Bool = false;
	public var ENTER:Bool = false;
	public var C:Bool = false;
	public var L:Bool = false;
	public var E:Bool = false;
	public var R:Bool = false;
	public var X:Bool = false;
	public var ONE:Bool = false;
	public var TWO:Bool = false;
	public var THREE:Bool = false;

	public function new()
	{
	}

	/** Clears every key, like a frame boundary. */
	public function reset():Void
	{
		for (field in Reflect.fields(this))
			Reflect.setField(this, field, false);
	}
}

/** `FlxG.keys` stand-in. */
class FlxKeys
{
	public var justPressed:FlxKeyMap = new FlxKeyMap();
	public var pressed:FlxKeyMap = new FlxKeyMap();

	public function new()
	{
	}
}

/** `FlxG.mouse` stand-in the spec drives directly. */
class FlxMouse
{
	public var x:Float = 0;
	public var y:Float = 0;
	public var wheel:Int = 0;
	public var justPressed:Bool = false;
	public var pressed:Bool = false;
	public var visible:Bool = true;

	public function new()
	{
	}
}

/** `FlxG.sound` stand-in that records what was played. */
class FlxSoundManager
{
	public var played:Array<String> = [];
	public var music:String = null;

	public function new()
	{
	}

	public function play(sound:FlxSound, ?volume:Float = 1):FlxSound
	{
		played.push(sound == null ? '' : Std.string(sound.key));
		return sound;
	}

	public function playMusic(music:FlxSound, ?volume:Float = 1, ?looped:Bool = true):FlxSound
	{
		this.music = music == null ? '' : Std.string(music.key);
		return music;
	}
}

/** Global game access stand-in for the lab state. */
class FlxG
{
	public static var width:Int = 1280;
	public static var height:Int = 720;
	public static var camera:FlxCamera = new FlxCamera();
	public static var mouse:FlxMouse = new FlxMouse();
	public static var keys:FlxKeys = new FlxKeys();
	public static var sound:FlxSoundManager = new FlxSoundManager();

	/** What the state switched to, so the spec can assert the exit path. */
	public static var switchedState:Dynamic = null;

	public static function switchState(next:Dynamic):Void
	{
		switchedState = next;
	}
}
