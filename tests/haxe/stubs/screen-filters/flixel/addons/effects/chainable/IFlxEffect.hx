package flixel.addons.effects.chainable;

import flixel.math.FlxPoint;
import openfl.display.BitmapData;

/**
 * Stand-in for the flixel-addons interface. The addon's contract is
 * `apply(pixels)` plus an optional draw offset; the spec records every applied
 * effect instead of touching pixels.
 */
interface IFlxEffect
{
  public var active:Bool;
  public var offset(default, null):FlxPoint;
  public function update(elapsed:Float):Void;
  public function apply(bitmapData:BitmapData):BitmapData;
}
