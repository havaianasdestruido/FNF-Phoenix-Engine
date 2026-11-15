package flixel.addons.effects.chainable;

import flixel.math.FlxPoint;
import openfl.display.BitmapData;

/** Shared bookkeeping for the effect stubs. */
class RecordedEffect implements IFlxEffect
{
  public var active:Bool = true;
  public var offset:FlxPoint = new FlxPoint();
  public var updates:Int = 0;
  public var applied:Int = 0;

  public function new() {}

  public function update(elapsed:Float):Void
    updates++;

  public function apply(bitmapData:BitmapData):BitmapData
  {
    applied++;
    return bitmapData;
  }
}
