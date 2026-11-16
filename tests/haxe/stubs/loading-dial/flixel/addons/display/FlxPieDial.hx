package flixel.addons.display;

import flixel.math.FlxPoint;
import flixel.util.FlxColor;

class FlxPieDial
{
  public var x:Float = 0;
  public var y:Float = 0;
  public var width:Float;
  public var height:Float;
  public var alpha:Float = 1;
  public var antialiasing:Bool = false;
  public var scrollFactor:FlxPoint = new FlxPoint();
  public var radius:Int;
  public var color:FlxColor;
  public var frames:Int;
  public var shape:FlxPieDialShape;
  public var clockwise:Bool;
  public var innerRadius:Int;
  public var amount(default, set):Float = 1;

  public function new(X:Float, Y:Float, Radius:Int, Color:FlxColor = FlxColor.WHITE,
      Frames:Int = 36, ?Shape:FlxPieDialShape, Clockwise:Bool = true, InnerRadius:Int = 0)
  {
    this.x = X;
    this.y = Y;
    this.radius = Radius;
    this.width = Radius * 2;
    this.height = Radius * 2;
    this.color = Color;
    this.frames = Frames;
    this.shape = Shape == null ? CIRCLE : Shape;
    this.clockwise = Clockwise;
    this.innerRadius = InnerRadius;
  }

  function set_amount(value:Float):Float
  {
    amount = value;
    return amount;
  }
}

enum FlxPieDialShape
{
  CIRCLE;
  SQUARE;
}
