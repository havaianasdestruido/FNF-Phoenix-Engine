package backend;

import backend.Controls;
import flixel.FlxBasic;
import flixel.FlxCamera;
import mobile.flixel.FlxVirtualPad;

class MusicBeatState
{
  public static var windowNameSuffix(default, set):String = '';
  static function set_windowNameSuffix(value:String):String return value;

  public var controls(get, never):Controls;
  inline function get_controls():Controls return PlayerSettings.player1.controls;

  public var members:Array<FlxBasic> = [];
  public var virtualPad:FlxVirtualPad = null;
  public var virtualPadAdded:String = null;
  public var virtualPadCameraAdded:Bool = false;
  public var openedSubStates:Array<Dynamic> = [];
  public var subState:Dynamic = null;
  public var created:Bool = false;
  public var destroyed:Bool = false;

  public function new() {}

  public function add(item:FlxBasic):FlxBasic
  {
    members.push(item);
    return item;
  }

  public function insert(position:Int, item:FlxBasic):FlxBasic
  {
    members.push(item);
    return item;
  }

  public function openSubState(next:Dynamic):Void
  {
    subState = next;
    openedSubStates.push(next);
  }

  public function closeSubState():Void
  {
    subState = null;
  }

  public function addVirtualPad(dpad:FlxDPadMode, action:FlxActionMode):Void
  {
    virtualPad = new FlxVirtualPad(dpad, action);
    virtualPadAdded = Std.string(dpad) + '/' + Std.string(action);
  }

  public function addVirtualPadCamera(defaultDrawTarget:Bool = false):Void
  {
    virtualPadCameraAdded = true;
  }

  function create():Void created = true;
  function update(elapsed:Float):Void {}
  function destroy():Void destroyed = true;

  public function onResize(width:Int, height:Int):Void {}
}
