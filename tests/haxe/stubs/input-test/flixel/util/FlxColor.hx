package flixel.util;

/** Just enough of the colour abstract for the page's styling calls. */
abstract FlxColor(Int) from Int to Int
{
  public static inline var WHITE:FlxColor = 0xFFFFFFFF;
  public static inline var BLACK:FlxColor = 0xFF000000;
}
