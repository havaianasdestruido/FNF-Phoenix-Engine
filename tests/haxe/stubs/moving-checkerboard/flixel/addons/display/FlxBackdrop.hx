package flixel.addons.display;

import flixel.math.FlxPoint;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;

/** Small behavioral surface used to execute the production backdrop in eval. */
class FlxBackdrop
{
  public var color:FlxColor;
  public var alpha:Float = 1;
  public var scale:FlxPoint = new FlxPoint();
  public var velocity:FlxPoint = new FlxPoint();
  public var scrollFactor:FlxPoint = new FlxPoint();
  public var antialiasing:Bool = false;
  public var visible:Bool = true;
  public var active:Bool = true;
  public var exists:Bool = true;

  public function new(graphic:Dynamic, axes:FlxAxes)
  {
    scale.set(1, 1);
  }

  public function updateHitbox():Void {}

  public function destroy():Void
  {
    exists = false;
  }
}
