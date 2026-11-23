package openfl.display;

/**
 * Tiny in-memory BitmapData stand-in. Specs fill `pixels` directly
 * (row-major, 0xAARRGGBB) and CoolUtil reads it through getPixel32.
 */
class BitmapData
{
  public var width:Int;
  public var height:Int;
  /** Row-major 0xAARRGGBB pixels, length == width * height. */
  public var pixels:Array<Int>;

  /** Creates a transparent (0) bitmap of the given size. */
  public function new(width:Int, height:Int)
  {
    this.width = width;
    this.height = height;
    pixels = [for (i in 0...(width * height)) 0];
  }

  /** Records a raw 0xAARRGGBB pixel; out-of-bounds writes are ignored. */
  public function setPixel32(x:Int, y:Int, color:Int):Void
  {
    if (x < 0 || y < 0 || x >= width || y >= height) return;
    pixels[y * width + x] = color;
  }

  /** Returns the recorded pixel, or 0 when out of bounds. */
  public function getPixel32(x:Int, y:Int):Int
  {
    if (x < 0 || y < 0 || x >= width || y >= height) return 0;
    return pixels[y * width + x];
  }
}
