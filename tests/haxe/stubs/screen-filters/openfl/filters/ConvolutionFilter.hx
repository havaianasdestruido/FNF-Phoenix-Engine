package openfl.filters;

/** Renderer-free stand-in for openfl.filters.ConvolutionFilter. */
class ConvolutionFilter extends BitmapFilter
{
  public var matrixX:Int;
  public var matrixY:Int;
  public var matrix:Array<Float>;
  public var divisor:Float;
  public var bias:Float;
  public var preserveAlpha:Bool;
  public var clamp:Bool;
  public var color:Int;
  public var alpha:Float;

  public function new(matrixX:Int = 0, matrixY:Int = 0, matrix:Array<Float> = null, divisor:Float = 1.0, bias:Float = 0.0,
      preserveAlpha:Bool = true, clamp:Bool = true, color:Int = 0, alpha:Float = 0.0)
  {
    super();
    this.matrixX = matrixX;
    this.matrixY = matrixY;
    this.matrix = matrix;
    this.divisor = divisor;
    this.bias = bias;
    this.preserveAlpha = preserveAlpha;
    this.clamp = clamp;
    this.color = color;
    this.alpha = alpha;
  }

  public function clone():BitmapFilter
    return new ConvolutionFilter(matrixX, matrixY, matrix, divisor, bias, preserveAlpha, clamp, color, alpha);
}
