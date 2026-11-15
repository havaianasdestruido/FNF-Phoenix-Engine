package flixel.addons.effects.chainable;

/** Records the arguments `ChainableEffects.glitch()` resolves. */
class FlxGlitchEffect extends RecordedEffect
{
  public var size:Int;
  public var delay:Float;
  public var direction:FlxGlitchDirection;
  public var strength:Int;

  public function new(Strength:Int = 4, Size:Int = 1, Delay:Float = 0.05, ?Direction:FlxGlitchDirection)
  {
    super();
    strength = Strength;
    size = Size;
    delay = Delay;
    direction = Direction;
  }
}

enum FlxGlitchDirection
{
  HORIZONTAL;
  VERTICAL;
}
