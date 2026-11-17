package flixel.tweens;

/** The one static surface `finish()` touches: reactivate every tween. */
class FlxTween
{
  public var finished:Bool = false;
  public var active:Bool = true;

  public static var globalManager:FlxTweenManager = new FlxTweenManager();
}

class FlxTweenManager
{
  public var tweens:Array<FlxTween> = [];

  public function new() {}

  public function forEach(fn:FlxTween->Void):Void
  {
    for (tween in tweens) fn(tween);
  }
}
