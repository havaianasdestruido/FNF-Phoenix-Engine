package openfl.display;

/** Renderer-free stand-in for openfl.display.BitmapData. */
class BitmapData
{
  public var width:Int;
  public var height:Int;
  public var disposed:Bool = false;

  public function new(width:Int = 0, height:Int = 0, transparent:Bool = true, fill:Int = 0)
  {
    this.width = width;
    this.height = height;
  }

  public function clone():BitmapData
    return new BitmapData(width, height);

  public function dispose():Void
    disposed = true;
}
