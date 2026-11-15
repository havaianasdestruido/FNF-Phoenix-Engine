package flixel;
class StubMusic
{
  public var stops:Int = 0;
  public function new() {}
  public function stop():Void stops++;
}
class FlxG { public static var sound = {music: new StubMusic()}; }
