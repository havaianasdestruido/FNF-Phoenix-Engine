package flixel;

/** Capturing stand-in for FlxG: records switchState calls and current state. */
class FlxG
{
  public static var state:Dynamic = null;
  public static var switchStateCalled:Bool = false;
  public static var nextStateFactory:Dynamic = null;

  public static function reset():Void
  {
    state = null;
    switchStateCalled = false;
    nextStateFactory = null;
  }

  public static function switchState(factory:Dynamic):Void
  {
    switchStateCalled = true;
    nextStateFactory = factory;
  }
}
