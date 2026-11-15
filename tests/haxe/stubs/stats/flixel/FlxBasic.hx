package flixel;

class FlxBasic
{
  public var ID:Int = 0;
  public var active:Bool = true;
  public var visible:Bool = true;
  public var exists:Bool = true;
  public var alive:Bool = true;
  public var cameras:Array<FlxCamera>;
  public var destroyed:Bool = false;

  public function new() {}
  public function update(elapsed:Float):Void {}
  public function destroy():Void destroyed = true;
}
