package objects;
class StrumNote
{
  public var x:Float;
  public var y:Float;
  public var downScroll:Bool = false;
  public var alpha:Float = 1;
  public var texture:String;
  public var useRGBShader:Bool = true;
  public function new(x:Float = 0, y:Float = 0, index:Int = 0, player:Int = 0) { this.x = x; this.y = y; }
  public function postAddedToGroup():Void {}
}
