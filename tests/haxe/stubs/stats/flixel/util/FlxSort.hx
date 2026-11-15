package flixel.util;

class FlxSort
{
  public static inline var ASCENDING:Int = -1;
  public static inline var DESCENDING:Int = 1;

  public static function byValues(order:Int, a:Float, b:Float):Int
  {
    if (a < b) return order;
    if (a > b) return -order;
    return 0;
  }
}
