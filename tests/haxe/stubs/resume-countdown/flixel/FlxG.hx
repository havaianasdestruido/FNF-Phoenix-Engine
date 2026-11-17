package flixel;

import flixel.sound.FlxSound;

/** The `FlxG.sound` pair the countdown touches. */
class FlxG
{
  public static var sound:FlxSoundManager = new FlxSoundManager();
}

class FlxSoundManager
{
  public var music:FlxSound = null;
  public var volume:Float = 0.7;

  public function new() {}
}
