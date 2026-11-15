package flixel;

import flixel.FlxCamera.FlxCameraList;

class FlxSaveStub
{
  public var data:Dynamic = {};
  public var flushCount:Int = 0;
  public var failFlush:Bool = false;

  public function new() {}

  public function flush():Bool
  {
    if (failFlush) throw 'simulated save flush error';
    flushCount++;
    return true;
  }

  public function reset():Void
  {
    data = {};
    flushCount = 0;
    failFlush = false;
  }
}

class FlxKeysJustPressed
{
  public var ESCAPE:Bool = false;
  public var TAB:Bool = false;
  public var C:Bool = false;
  public var R:Bool = false;
  public function new() {}
}

class FlxKeysStub
{
  public var justPressed:FlxKeysJustPressed = new FlxKeysJustPressed();
  public function new() {}
}

class FlxMouseStub
{
  public var visible:Bool = false;
  public var wheel:Int = 0;
  public var deltaX:Float = 0;
  public var deltaY:Float = 0;
  public function new() {}
}

class FlxSoundStub
{
  public var played:Array<String> = [];
  public function new() {}
  public function play(asset:String, volume:Float = 1):Void
    played.push(asset);
}

class FlxG
{
  public static var width:Int = 1280;
  public static var height:Int = 720;
  public static var save:FlxSaveStub = new FlxSaveStub();
  public static var keys:FlxKeysStub = new FlxKeysStub();
  public static var mouse:FlxMouseStub = new FlxMouseStub();
  public static var sound:FlxSoundStub = new FlxSoundStub();
  public static var camera:FlxCamera = new FlxCamera();
  public static var cameras:FlxCameraList = new FlxCameraList();
  public static var state:Dynamic = null;
  public static var switchedStates:Array<Dynamic> = [];

  public static function switchState(nextState:Dynamic):Void
  {
    if (Reflect.isFunction(nextState))
      switchedStates.push(Reflect.callMethod(null, nextState, []));
    else
      switchedStates.push(nextState);
  }

  public static function reset():Void
  {
    width = 1280;
    height = 720;
    save = new FlxSaveStub();
    keys = new FlxKeysStub();
    mouse = new FlxMouseStub();
    sound = new FlxSoundStub();
    camera = new FlxCamera();
    cameras = new FlxCameraList();
    cameras.list.push(camera);
    state = null;
    switchedStates = [];
  }
}
