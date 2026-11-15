package openfl.filters;

/**
 * Renderer-free stand-in for openfl.filters.BlurFilter. The real class builds a
 * GLSL pass; here it only records what was asked for, so the spec can check the
 * argument plumbing.
 */
class BlurFilter extends BitmapFilter
{
  public var blurX:Float;
  public var blurY:Float;
  public var quality:Int;

  public function new(blurX:Float = 4, blurY:Float = 4, quality:Int = 1)
  {
    super();
    this.blurX = blurX;
    this.blurY = blurY;
    this.quality = quality;
  }

  public function clone():BitmapFilter
    return new BlurFilter(blurX, blurY, quality);
}
