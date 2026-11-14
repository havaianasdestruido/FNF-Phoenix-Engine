package flixel.math;

class FlxMath
{
  public static function bound(value:Float, ?min:Float, ?max:Float):Float
  {
    var out:Float = value;
    if (min != null && out < min) out = min;
    if (max != null && out > max) out = max;
    return out;
  }

  public static function roundDecimal(value:Float, precision:Int):Float
  {
    var mult:Float = 1;
    for (_ in 0...precision) mult *= 10;
    return Math.round(value * mult) / mult;
  }

  public static function lerp(a:Float, b:Float, ratio:Float):Float
    return a + ratio * (b - a);
}
