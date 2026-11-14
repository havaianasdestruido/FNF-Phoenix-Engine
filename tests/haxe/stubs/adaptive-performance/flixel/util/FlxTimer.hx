package flixel.util;
class FlxTimer
{
  public var cancelled:Bool = false;
  public var duration:Float = 0;
  public var onComplete:FlxTimer->Void;
  public function new() {}
  public function cancel():Void cancelled = true;
  public function start(seconds:Float, callback:FlxTimer->Void):FlxTimer
  {
    cancelled = false;
    duration = seconds;
    onComplete = callback;
    return this;
  }
}
