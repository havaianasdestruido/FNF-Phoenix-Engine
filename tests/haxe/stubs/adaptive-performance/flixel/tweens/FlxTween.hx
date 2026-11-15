package flixel.tweens;
class FlxTween
{
  public static var cancelled:Array<Dynamic> = [];
  public static function cancelTweensOf(target:Dynamic):Void cancelled.push(target);
}
