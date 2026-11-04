package backend;

import backend.Controls;
import flixel.FlxSprite;
import flixel.util.FlxAxes;

/** The base state's surface the diagnostics page actually uses. */
class MusicBeatState
{
  public static var windowNameSuffix(default, set):String = '';
  static function set_windowNameSuffix(value:String):String return value;

  public var persistentUpdate:Bool = false;
  public var controls:Controls = new Controls();
  public var virtualPadAdded:String = null;
  public var virtualPadCamera:Bool = false;
  public var created:Bool = false;
  public var updates:Int = 0;
  public var destroyed:Bool = false;
  public var resizes:Int = 0;

  public function new() {}

  public function add(sprite:FlxSprite):FlxSprite return sprite;
  public function addVirtualPad(DPad:Dynamic, Action:Dynamic):Void
    virtualPadAdded = Std.string(DPad) + '/' + Std.string(Action);
  public function addVirtualPadCamera(?defaultDrawTarget:Bool = false):Void virtualPadCamera = true;

  function create():Void created = true;
  function update(elapsed:Float):Void updates++;
  function destroy():Void destroyed = true;

  public function onResize(width:Int, height:Int):Void
  {
    resizes++;
  }
}
