package flixel.util;

/** Abstract stand-in with just the constants the filter API compares. */
enum abstract FlxColor(Int) from Int to Int
{
  public static inline var TRANSPARENT:Int = 0x00000000;
  public static inline var WHITE:Int = 0xFFFFFFFF;
  public static var GRAY:Int = 0xFF808080;
  public static inline var BLACK:Int = 0xFF000000;
  public static inline var GREEN:Int = 0xFF00FF00;
  public static inline var BLUE:Int = 0xFF0000FF;
  public static inline var RED:Int = 0xFFFF0000;
  public static inline var YELLOW:Int = 0xFFFFFF00;

  public static inline function fromInt(value:Int):FlxColor
    return value;
}
