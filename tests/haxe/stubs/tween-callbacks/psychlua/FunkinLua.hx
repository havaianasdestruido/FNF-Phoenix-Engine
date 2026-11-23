package psychlua;

class FunkinLua
{
  public static final functions:Map<String, Dynamic> = new Map();

  public var scriptName:String = 'test.lua';
  public var lua:Dynamic;
  public var nextTarget:Dynamic = {x: 0.0, y: 0.0, angle: 0.0, alpha: 1.0, zoom: 1.0, direction: 0.0, color: 0, scale: {x: 1.0, y: 1.0}};

  public function new() {}

  public static function registerFunction(name:String, callback:Dynamic):Void
  {
    functions.set(name, callback);
  }

  public function tweenPrepare(tag:String, vars:String):Dynamic return nextTarget;
  public function cancelTween(tag:String):Void {}
  public function cancelTimer(tag:String):Void {}
}

class LuaTweenOptions
{
  public var type:Int = 0;
  public var ease:Dynamic;
  public var startDelay:Float = 0;
  public var loopDelay:Float = 0;
  public var onUpdate:String;
  public var onStart:String;
  public var onComplete:String;

  public function new() {}
}
