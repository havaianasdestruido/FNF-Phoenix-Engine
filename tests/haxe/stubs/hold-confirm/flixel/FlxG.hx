package flixel;

import flixel.input.mouse.FlxMouse;
import flixel.input.touch.FlxTouchManager;

class FlxCameraList
{
  public var list:Array<FlxCamera> = [new FlxCamera()];
  public function new() {}
}

class FlxSoundManager
{
  public function new() {}
  public function play(sound:Dynamic, volume:Float = 1):Dynamic return null;
}

class FlxG
{
  public static var width:Int = 1280;
  public static var height:Int = 720;
  public static var mouse:FlxMouse = new FlxMouse();
  public static var touches:FlxTouchManager = new FlxTouchManager();
  public static var cameras:FlxCameraList = new FlxCameraList();
  public static var sound:FlxSoundManager = new FlxSoundManager();
}
