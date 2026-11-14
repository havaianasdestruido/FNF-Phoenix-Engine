package;
class FlxObject
{
  public var x:Float = 0;
  public var y:Float = 0;
  public function new() {}
}
class FlxPoint
{
  public var x:Float;
  public var y:Float;
  public function new(x:Float, y:Float) { this.x = x; this.y = y; }
  public static function get(x:Float, y:Float):FlxPoint return new FlxPoint(x, y);
  public function put():Void {}
}
class FlxTypedGroup<T>
{
  public var members:Array<T> = [];
  public var length(get, never):Int;
  function get_length():Int return members.length;
  public function new() {}
  public function add(item:T):T { members.push(item); return item; }
  public function remove(item:T, splice:Bool):T { members.remove(item); return item; }
  public function recycle(cls:Class<T>):T return Type.createInstance(cls, []);
}
class FlxG
{
  public static var width:Int = 1280;
  public static var height:Int = 720;
}
class FlxTween
{
  public static function tween(obj:Dynamic, values:Dynamic, duration:Float, ?options:Dynamic):Dynamic return null;
}
class FlxEase { public static var circOut:Dynamic; }
class Paths
{
  public static function fileExists(path:String, kind:AssetType):Bool return false;
}
enum AssetType { IMAGE; }
