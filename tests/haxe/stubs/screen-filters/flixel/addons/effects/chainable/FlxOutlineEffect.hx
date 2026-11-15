package flixel.addons.effects.chainable;

import flixel.util.FlxColor;

/** Records the arguments `ChainableEffects.outline()` resolves. */
class FlxOutlineEffect extends RecordedEffect
{
  public var dirty:Bool = true;
  public var mode:FlxOutlineMode;
  public var color:FlxColor;
  public var thickness:Int;
  public var threshold:Int;
  public var quality:Float;

  public function new(?Mode:FlxOutlineMode, Color:FlxColor = FlxColor.WHITE, Thickness:Int = 1, Threshold:Int = 0, Quality:Float = 1)
  {
    super();
    mode = (Mode == null) ? FAST : Mode;
    color = Color;
    thickness = Thickness;
    threshold = Threshold;
    quality = Quality;
  }
}

enum FlxOutlineMode
{
  FAST;
  NORMAL;
  PIXEL_BY_PIXEL;
}
