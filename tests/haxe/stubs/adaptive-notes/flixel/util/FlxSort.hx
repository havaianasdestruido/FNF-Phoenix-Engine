package flixel.util;
class FlxSort
{
  public static inline final ASCENDING:Int = -1;
  public static inline final DESCENDING:Int = 1;
  public static function byValues(order:Int, a:Float, b:Float):Int return a == b ? 0 : (a < b ? order : -order);
}
