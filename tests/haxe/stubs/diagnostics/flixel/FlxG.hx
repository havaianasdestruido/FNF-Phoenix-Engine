package flixel;

import flixel.FlxCamera;
import flixel.math.FlxPoint;

/** Viewport, input and process stand-ins for the diagnostics report and page. */
class FlxScale
{
  public var x:Float = 1;
  public function new() {}
}

class FlxScaleMode
{
  public var scale:FlxScale = new FlxScale();
  public function new() {}
}

class FlxMouse
{
  public var wheel:Int = 0;
  public function new() {}
}

class FlxKeyList
{
  public var ESCAPE:Bool = false;
  public var C:Bool = false;
  public var R:Bool = false;
  public function new() {}
}

class FlxKeys
{
  public var justPressed:FlxKeyList = new FlxKeyList();
  public function new() {}
}

class FlxGame
{
  /** Milliseconds since the game started, like the real `FlxGame.ticks`. */
  public var ticks:Float = 0;
  public function new() {}
}

class FlxState
{
  public function new() {}
}

class FlxG
{
  /** What `FlxG.switchState` was handed, so the spec can assert the page's exit. */
  public static var switchedToInt:Array<String> = [];

  // flixel 5 exposes the stage size as Ints (see source/source-haxelib-patches/flixel/FlxGame.hx).
  public static var width:Int = 1280;
  public static var height:Int = 720;
  public static var fullscreen:Bool = false;
  public static var updateFramerate:Int = 60;
  public static var drawFramerate:Int = 60;
  public static var scaleMode:FlxScaleMode = new FlxScaleMode();
  public static var mouse:FlxMouse = new FlxMouse();
  public static var keys:FlxKeys = new FlxKeys();
  public static var game:FlxGame = new FlxGame();
  public static var state:FlxState = new FlxState();
  public static var cameras:FlxCameraList = new FlxCameraList();

  public static function switchState(?NewState:Dynamic):Void
    switchedToInt.push(Std.string(NewState));
}
