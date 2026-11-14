package backend;

import backend.Controls;
import flixel.FlxBasic;
import flixel.FlxCamera;
import mobile.flixel.FlxVirtualPad;

class MusicBeatSubstate
{
  public var controls(get, never):Controls;
  inline function get_controls():Controls return PlayerSettings.player1.controls;

  public var cameras:Array<FlxCamera>;
  public var members:Array<FlxBasic> = [];
  public var virtualPad:FlxVirtualPad = null;
  public var closed:Bool = false;

  public function new() {}

  public function add(item:FlxBasic):FlxBasic
  {
    members.push(item);
    return item;
  }

  public function addVirtualPad(dpad:FlxDPadMode, action:FlxActionMode):Void
  {
    virtualPad = new FlxVirtualPad(dpad, action);
  }

  public function addVirtualPadCamera(defaultDrawTarget:Bool = false):Void {}

  public function close():Void closed = true;

  function update(elapsed:Float):Void {}
  function destroy():Void {}

  public function onResize(width:Int, height:Int):Void {}
}
