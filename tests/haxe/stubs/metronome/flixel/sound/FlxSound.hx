package flixel.sound;

class FlxSound
{
  public var exists:Bool = true;
  public var volume:Float = 1;
  public var pitch:Float = 1;
  public var plays:Int = 0;
  public var stops:Int = 0;
  public var restarted:Bool = false;

  public function new() {}

  public function play(forceRestart:Bool = false):FlxSound
  {
    plays++;
    restarted = forceRestart;
    return this;
  }

  public function stop():FlxSound
  {
    stops++;
    return this;
  }
}
