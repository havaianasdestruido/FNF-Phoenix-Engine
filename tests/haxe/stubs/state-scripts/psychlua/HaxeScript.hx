package psychlua;

/**
 * Scripted stand-in for HaxeScript. Per-script return values are queued by
 * path and method name in `responses`; scripts whose path is listed in
 * `closeOnCreate` report themselves closed, which is how the load test
 * exercises the "skip closed scripts" branch without a real script engine.
 */
class HaxeScript
{
  public static var responses:Map<String, Array<Dynamic>> = new Map();
  public static var closeOnCreate:Array<String> = [];

  public var path:String;
  public var parent:Dynamic;
  public var closed:Bool = false;
  public var stopped:Bool = false;
  public var calls:Array<Dynamic> = [];
  public var sets:Map<String, Dynamic> = new Map();

  public function new(path:String, ?parent:Dynamic)
  {
    this.path = path;
    this.parent = parent;
    if (closeOnCreate.indexOf(path) >= 0) closed = true;
  }

  public static function reset():Void
  {
    responses = new Map();
    closeOnCreate = [];
  }

  public function call(name:String, args:Array<Dynamic>):Dynamic
  {
    calls.push({name: name, args: args});
    var key = path + '|' + name;
    var queue = responses.get(key);
    if (queue == null || queue.length == 0) return '##PSYCHLUA_FUNCTIONCONTINUE';
    return queue.shift();
  }

  public function set(name:String, value:Dynamic):Void
  {
    sets.set(name, value);
  }

  public function stop():Void
  {
    stopped = true;
  }
}
