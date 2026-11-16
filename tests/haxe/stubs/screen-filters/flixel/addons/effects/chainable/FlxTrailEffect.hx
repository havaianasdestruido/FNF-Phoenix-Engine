package flixel.addons.effects.chainable;

/** Records which effect sprite a trail was attached to. */
class FlxTrailEffect extends RecordedEffect
{
  public var target:FlxEffectSprite;
  public var length:Int;
  public var alpha:Float;
  public var framesDelay:Int;
  public var cachePixels:Bool;

  public function new(Target:FlxEffectSprite, Length:Int = 10, Alpha:Float = 0.5, FramesDelay:Int = 2, CachePixels:Bool = true)
  {
    super();
    target = Target;
    length = Length;
    alpha = Alpha;
    framesDelay = FramesDelay;
    cachePixels = CachePixels;
  }

  public function clear():Void {}
}
