package flixel.tweens;

class FlxTween
{
  public var percent:Float = 1;
  public function new() {}
  public function cancel():Void {}

  public static function num(fromValue:Float, toValue:Float, duration:Float = 1,
      ?options:Dynamic, ?tweenFunction:Float->Void):FlxTween
  {
    if (tweenFunction != null) tweenFunction(toValue);
    return new FlxTween();
  }

  public static function tween(object:Dynamic, values:Dynamic, duration:Float = 1, ?options:Dynamic):FlxTween
    return new FlxTween();
}
