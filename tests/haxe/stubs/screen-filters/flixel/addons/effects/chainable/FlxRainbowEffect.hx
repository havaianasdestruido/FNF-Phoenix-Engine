package flixel.addons.effects.chainable;

/** Records the arguments `ChainableEffects.rainbow()` resolves. */
class FlxRainbowEffect extends RecordedEffect
{
  public var speed:Float;
  public var alpha:Float;
  public var brightness:Float;
  public var startHue:Int;

  public function new(Alpha:Float = 1, Brightness:Float = 1, Speed:Float = 5, StartHue:Int = 0)
  {
    super();
    alpha = Alpha;
    brightness = Brightness;
    speed = Speed;
    startHue = StartHue;
  }
}
