package flixel;
import play.PlayState;
class FlxG
{
  public static var width:Int = 1280;
  public static var height:Int = 720;
  public static var drawFramerate:Int = 60;
  public static var state:PlayState;
  public static var game:MockGame = new MockGame();
  public static var signals:Signals = new Signals();
}
class MockGame
{
  public var _lostFocus:Bool = false;
  public function new() {}
}
class Signals
{
  public var postDraw:Signal = new Signal();
  public function new() {}
}
class Signal
{
  public var listeners:Array<Void->Void> = [];
  public function new() {}
  public function add(listener:Void->Void):Void listeners.push(listener);
  public function remove(listener:Void->Void):Void listeners.remove(listener);
  public function dispatch():Void for (listener in listeners.copy()) listener();
}
