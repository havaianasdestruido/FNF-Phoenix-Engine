package psychlua;

class PythonScript
{
  public static var registeredFunctions:Map<String, Dynamic> = [];

  public function new() {}

  public static function registerFunction(name:String, func:Dynamic):Void
    registeredFunctions.set(name, func);

  public function pyTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:Dynamic = 0):Void {}
}
