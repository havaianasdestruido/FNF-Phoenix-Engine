package flixel;

import flixel.math.FlxPoint;
import flixel.util.FlxColor;

class FlxCameraList
{
  public var list:Array<FlxCamera> = [];
  public var added:Array<FlxCamera> = [];
  public var removed:Array<FlxCamera> = [];

  public function new() {}

  public function add(camera:FlxCamera, defaultDrawTarget:Bool = true):FlxCamera
  {
    list.push(camera);
    added.push(camera);
    return camera;
  }

  public function remove(camera:FlxCamera, destroy:Bool = true):Void
  {
    list.remove(camera);
    removed.push(camera);
  }
}

class FlxCamera
{
  public var bgColor:FlxColor = 0xFF000000;
  public var scroll:FlxPoint = new FlxPoint();
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Int = 1280;
  public var height:Int = 720;
  public var followed:FlxObject = null;

  public function new(x:Int = 0, y:Int = 0, width:Int = 1280, height:Int = 720)
  {
    this.x = x;
    this.y = y;
    this.width = width;
    this.height = height;
  }

  public function setPosition(newX:Float, newY:Float):Void
  {
    x = newX;
    y = newY;
  }

  public function setSize(newWidth:Int, newHeight:Int):Void
  {
    width = newWidth;
    height = newHeight;
  }

  public function follow(target:FlxObject, ?style:Dynamic, lerp:Float = 1):Void
  {
    followed = target;
  }
}
