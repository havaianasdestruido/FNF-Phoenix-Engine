package lime.app;

class ExitSignal
{
  public var listeners:Array<Int->Void> = [];

  public function new() {}

  public function add(listener:Int->Void):Void
  {
    if (!listeners.contains(listener)) listeners.push(listener);
  }

  public function remove(listener:Int->Void):Void
  {
    var i:Int = listeners.length - 1;
    while (i >= 0)
    {
      if (Reflect.compareMethods(listeners[i], listener))
        listeners.splice(i, 1);
      i--;
    }
  }

  public function dispatch(code:Int = 0):Void
  {
    for (listener in listeners.copy()) listener(code);
  }
}

class Application
{
  public static var current:Application = new Application();
  public var onExit:ExitSignal = new ExitSignal();

  public function new() {}

  public static function reset():Void
  {
    current = new Application();
  }
}
