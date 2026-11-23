class FlxTimer
{
  public var finished:Bool = true;
  public var loops:Int = 1;
  public var loopsLeft:Int = 0;

  public function new() {}

  public function start(time:Float, callback:FlxTimer->Void, loops:Int):FlxTimer return this;
}
