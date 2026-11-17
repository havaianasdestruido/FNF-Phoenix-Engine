package flixel.addons.display;

import flixel.graphics.FlxGraphic;
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

  /** Graphic the production class last loaded, or null when none did. */
  public var graphic:FlxGraphic = null;

  public function new(graphic:Dynamic, axes:FlxAxes)
  {
    scale.set(1, 1);
  }

  /** Mirrors FlxSprite.loadGraphic: the backdrop keeps drawing the new tile. */
  public function loadGraphic(graphic:FlxGraphic):Void
  {
    this.graphic = graphic;
  }

  public function updateHitbox():Void {}

  public function destroy():Void
  {
    exists = false;
  }
}
