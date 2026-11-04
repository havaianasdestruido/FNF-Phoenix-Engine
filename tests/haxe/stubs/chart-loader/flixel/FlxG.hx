package flixel;

import flixel.sound.FlxSound;

class FlxSoundList
{
  public function new() {}
  public function add(sound:FlxSound):Void {}
}

class FlxSoundManager
{
  public var list:FlxSoundList = new FlxSoundList();
  public function new() {}
}

class FlxRandom
{
  public function new() {}
  public function int(min:Int, max:Int):Int return min;
}

class FlxG
{
  public static var sound:FlxSoundManager = new FlxSoundManager();
  public static var random:FlxRandom = new FlxRandom();
}
