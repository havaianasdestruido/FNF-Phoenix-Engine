package openfl.filters;

import openfl.display.BitmapData;
import openfl.geom.Point;

/** Renderer-free stand-in for openfl.filters.DisplacementMapFilter. */
class DisplacementMapFilter extends BitmapFilter
{
  public var mapBitmap:BitmapData;
  public var mapPoint:Point;
  public var componentX:Int;
  public var componentY:Int;
  public var scaleX:Float;
  public var scaleY:Float;
  public var mode:DisplacementMapFilterMode;
  public var color:Int;
  public var alpha:Float;

  public function new(mapBitmap:BitmapData = null, mapPoint:Point = null, componentX:Int = 0, componentY:Int = 0, scaleX:Float = 0.0,
      scaleY:Float = 0.0, mode:DisplacementMapFilterMode = WRAP, color:Int = 0, alpha:Float = 0.0)
  {
    super();
    this.mapBitmap = mapBitmap;
    this.mapPoint = mapPoint;
    this.componentX = componentX;
    this.componentY = componentY;
    this.scaleX = scaleX;
    this.scaleY = scaleY;
    this.mode = mode;
    this.color = color;
    this.alpha = alpha;
  }

  public function clone():BitmapFilter
    return new DisplacementMapFilter(mapBitmap, mapPoint, componentX, componentY, scaleX, scaleY, mode, color, alpha);
}
