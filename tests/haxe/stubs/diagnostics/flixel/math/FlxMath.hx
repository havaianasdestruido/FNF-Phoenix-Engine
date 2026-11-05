package flixel.math;

class FlxMath
{
  public static function bound(value:Float, min:Float, max:Float):Float
    return value < min ? min : (value > max ? max : value);
}
