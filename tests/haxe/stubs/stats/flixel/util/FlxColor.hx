package flixel.util;

abstract FlxColor(Int) from Int to Int
{
  public static inline var TRANSPARENT:FlxColor = 0x00000000;
  public static inline var WHITE:FlxColor = 0xFFFFFFFF;
  public static inline var BLACK:FlxColor = 0xFF000000;
  public static inline var RED:FlxColor = 0xFFFF0000;
  public static inline var GRAY:FlxColor = 0xFF808080;

  public var alpha(get, set):Int;

  inline function get_alpha():Int
    return (this >> 24) & 0xFF;

  inline function set_alpha(v:Int):Int
    return this = (this & 0x00FFFFFF) | ((v & 0xFF) << 24);
}
