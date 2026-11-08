package flixel;

class FlxCamera
{
  public var scroll = new Point();
  public var flashSprite = new Point();
  public var bgColor = new Color();
  public var zoom:Float = 1;
  public var angle:Float = 0;
  public var alpha:Float = 1;
  public var visible:Bool = true;
  public var width:Int = 1280;
  public var height:Int = 720;
  public var scaleX:Float = 1;
  public var scaleY:Float = 1;
  public var filters:Array<Dynamic> = [];

  public function new() {}

  public function addShader(shader:Dynamic):Void
  {
    filters.push(shader);
  }

  public function setScale(x:Float, y:Float):Void
  {
    scaleX = x;
    scaleY = y;
  }
}

private class Point
{
  public var x:Float = 0;
  public var y:Float = 0;

  public function new() {}

  public function set(x:Float, y:Float):Void
  {
    this.x = x;
    this.y = y;
  }

  public function copyFrom(other:Point):Void
  {
    set(other.x, other.y);
  }
}

private class Color
{
  public var alpha:Int = 255;

  public function new() {}
}
