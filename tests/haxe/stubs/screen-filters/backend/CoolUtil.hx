package backend;

import flixel.util.FlxColor;

/** Colour parsing stub mirroring `CoolUtil.colorFromString`. */
class CoolUtil
{
  public static function colorFromString(color:String):FlxColor
  {
    if (color == null) return FlxColor.WHITE;
    final text:String = color.trim().toLowerCase();
    return switch (text)
    {
      case 'red': FlxColor.RED;
      case 'green': FlxColor.GREEN;
      case 'white': FlxColor.WHITE;
      case 'black': FlxColor.BLACK;
      case _: 0xFF123456;
    };
  }
}
