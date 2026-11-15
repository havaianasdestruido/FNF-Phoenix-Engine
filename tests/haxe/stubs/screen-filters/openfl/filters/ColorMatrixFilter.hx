package openfl.filters;

/** Renderer-free stand-in for openfl.filters.ColorMatrixFilter. */
class ColorMatrixFilter extends BitmapFilter
{
  public var matrix:Array<Float>;

  public function new(matrix:Array<Float> = null)
  {
    super();
    this.matrix = matrix;
  }

  public function clone():BitmapFilter
    return new ColorMatrixFilter(matrix);
}
