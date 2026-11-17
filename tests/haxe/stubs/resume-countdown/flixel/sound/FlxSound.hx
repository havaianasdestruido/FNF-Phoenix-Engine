package flixel.sound;

/** Sound surface the countdown drives: volume plus a play() it can observe. */
class FlxSound
{
  public var volume:Float = 1;
  public var pitch:Float = 1;
  public var playedCount:Int = 0;

  public function new() {}

  public function play():Void
  {
    playedCount++;
  }
}
