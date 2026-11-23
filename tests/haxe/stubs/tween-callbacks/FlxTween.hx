class FlxTween
{
  public static var calls:Int = 0;
  public static var lastTarget:Dynamic;
  public static var lastValues:Dynamic;

  public var type:Int = 0;

  public function new() {}

  public static function tween(target:Dynamic, values:Dynamic, duration:Float, ?options:Dynamic):FlxTween
  {
    calls++;
    lastTarget = target;
    lastValues = values;
    return new FlxTween();
  }

  public static function color(target:Dynamic, duration:Float, start:Dynamic, end:Dynamic, ?options:Dynamic):FlxTween
  {
    return new FlxTween();
  }
}
