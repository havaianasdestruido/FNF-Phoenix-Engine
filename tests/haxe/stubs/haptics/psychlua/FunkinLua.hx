package psychlua;

class FunkinLua
{
  public static var registeredFunctions:Map<String, Dynamic> = [];

  public var lua:Dynamic = null;

  public function new() {}

  public static function registerFunction(name:String, func:Dynamic):Void
    registeredFunctions.set(name, func);
}
