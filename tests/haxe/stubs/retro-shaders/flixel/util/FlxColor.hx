package flixel.util;

/**
 * Stand-in for flixel's `FlxColor` abstract: an `Int` with the 0-1 channel
 * getters `shaders.SilhouetteEffect` reads and the `from Int` implicit cast that
 * lets a script pass `0xFF0000`. Only the members the production code touches are
 * here; the real abstract carries the full colour API (`fromString`, HSB
 * conversion, ...), which `backend.CoolUtil.colorFromString` uses on the Lua side.
 */
abstract FlxColor(Int) from Int to Int
{
  public static inline var BLACK:FlxColor = 0xFF000000;
  public static inline var WHITE:FlxColor = 0xFFFFFFFF;

  public var red(get, never):Int;
  public var green(get, never):Int;
  public var blue(get, never):Int;
  public var redFloat(get, never):Float;
  public var greenFloat(get, never):Float;
  public var blueFloat(get, never):Float;

  inline function get_red():Int
    return (this >> 16) & 0xFF;

  inline function get_green():Int
    return (this >> 8) & 0xFF;

  inline function get_blue():Int
    return this & 0xFF;

  inline function get_redFloat():Float
    return get_red() / 255;

  inline function get_greenFloat():Float
    return get_green() / 255;

  inline function get_blueFloat():Float
    return get_blue() / 255;

  public static function fromInt(value:Int):FlxColor
    return value;
}
