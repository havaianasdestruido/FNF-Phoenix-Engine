package psychlua;

class PythonScript
{
	public function new() {}

	public static function registerFunction(name:String, func:Dynamic):Void {}

	public function pyTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:Dynamic = null):Void {}
}
