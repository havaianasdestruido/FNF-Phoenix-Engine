package flixel.addons.effects.chainable;

/** Records the arguments `ChainableEffects.wave()` resolves. */
class FlxWaveEffect extends RecordedEffect
{
  public var mode:FlxWaveMode;
  public var speed:Float;
  public var center:Float;
  public var direction:FlxWaveDirection;
  public var wavelength:Int;
  public var strength:Int;

  public function new(?Mode:FlxWaveMode, Strength:Int = 10, Center:Float = 0.5, Speed:Float = 3, Wavelength:Int = 5, ?Direction:FlxWaveDirection,
      InterlaceOffset:Float = 0)
  {
    super();
    mode = Mode;
    strength = Strength;
    center = Center;
    speed = Speed;
    wavelength = Wavelength;
    direction = Direction;
  }
}

enum FlxWaveMode
{
  ALL;
  START;
  END;
}

enum FlxWaveDirection
{
  HORIZONTAL;
  VERTICAL;
}
