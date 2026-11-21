package flixel;

/**
 * Minimal FlxG stub for the GDI HPPD test song spec. GDIEffects.init()
 * hooks into FlxG.signals.preUpdate and reads FlxG.elapsed; the stub
 * provides both so the real GDIEffects class compiles and runs on the
 * Haxe interpreter without Flixel.
 */
class FlxG
{
  public static var width:Int = 1280;
  public static var height:Int = 720;
  public static var elapsed:Float = 0;
  public static var signals:Signals = new Signals();
}

class Signals
{
  public var preUpdate:Signal = new Signal();
  public function new() {}
}

class Signal
{
  public var listeners:Array<Void->Void> = [];
  public function new() {}
  public function add(listener:Void->Void):Void listeners.push(listener);
  public function remove(listener:Void->Void):Void listeners.remove(listener);
  public function dispatch():Void
  {
    for (listener in listeners.copy())
      listener();
  }
}
