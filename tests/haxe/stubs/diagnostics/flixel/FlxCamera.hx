package flixel;

import flixel.math.FlxPoint;

class FlxCameraScroll
{
  public var y:Float = 0;
  public function new() {}
}

/** Cameras are recorded so the spec can prove the page cleans up after itself. */
class FlxCameraList
{
  public var added:Array<FlxCamera> = [];
  public var removed:Array<FlxCamera> = [];
  public function new() {}
  public function add(camera:FlxCamera, transparent:Bool):Void added.push(camera);
  public function remove(camera:FlxCamera, destroy:Bool = true):Void removed.push(camera);
}

class FlxCamera
{
  public var bgColor:Int = 0xFF000000;
  public var scroll:FlxPoint = new FlxPoint();
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Int = 0;
  public var height:Int = 0;
  public function new() {}
  public function setPosition(x:Float, y:Float):Void { this.x = x; this.y = y; }
  public function setSize(width:Int, height:Int):Void { this.width = width; this.height = height; }
}
