package flixel;

import flixel.math.FlxPoint;

/** Camera surface used by the overlay: size, zoom and rotation. */
class FlxCamera
{
  public var width:Int = 1280;
  public var height:Int = 720;
  public var zoom:Float = 1;
  public var angle:Float = 0;
  public var scroll:FlxPoint = new FlxPoint();
  public var visible:Bool = true;
  public var exists:Bool = true;
  public var defaultCameras:Array<FlxCamera> = null;

  public function new() {}
}
