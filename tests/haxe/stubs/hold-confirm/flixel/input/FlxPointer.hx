package flixel.input;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxObject;

class FlxPointer
{
  public var pressed:Bool = false;
  public var justPressed:Bool = false;
  public var justReleased:Bool = false;
  /** Set by the spec to pretend the pointer is over the tested hit area. */
  public var overlapResult:Bool = false;
  /** When true, overlaps() uses pointX/pointY against the object's bounds. */
  public var usePoint:Bool = false;
  public var pointX:Float = 0;
  public var pointY:Float = 0;

  public function new() {}

  public function overlaps(object:FlxBasic, ?camera:FlxCamera):Bool
  {
    if (!usePoint) return overlapResult;
    var o:FlxObject = cast object;
    return pointX >= o.x && pointX < o.x + o.width
      && pointY >= o.y && pointY < o.y + o.height;
  }
}
