package flixel.text;
class FlxText
{
  public var x:Float;
  public var y:Float;
  public var text:String;
  public var visible:Bool = true;
  public var borderSize:Float = 0;
  public var cameras:Array<Dynamic>;
  public var scrollFactor:MockPoint = new MockPoint();
  public function new(x:Float, y:Float, width:Float, text:String, size:Int)
  {
    this.x = x;
    this.y = y;
    this.text = text;
  }
  public function setFormat(font:String, size:Int, color:Int, align:FlxTextAlign,
    style:FlxTextBorderStyle, border:Int):Void {}
}
class MockPoint
{
  public function new() {}
  public function set():Void {}
}
enum abstract FlxTextAlign(String) { var LEFT = 'left'; }
enum FlxTextBorderStyle { OUTLINE; }
