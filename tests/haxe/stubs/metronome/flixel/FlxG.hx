package flixel;

import flixel.sound.FlxSound;

class FlxG
{
  public static var sound:SoundFrontEnd = new SoundFrontEnd();
}

class SoundFrontEnd
{
  public var loads:Int = 0;
  public var lastSound:FlxSound = null;

  public function new() {}

  public function load(asset:Dynamic):FlxSound
  {
    loads++;
    lastSound = new FlxSound();
    return lastSound;
  }

  public function reset():Void
  {
    if (lastSound != null) lastSound.exists = false;
    loads = 0;
    lastSound = null;
  }
}
