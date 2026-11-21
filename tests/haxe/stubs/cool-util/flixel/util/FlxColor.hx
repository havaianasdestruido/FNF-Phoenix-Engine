package flixel.util;

/**
 * Minimal FlxColor stand-in: an Int-backed colour with the named constants
 * CoolUtil uses and a strict fromString (hex #RGB/#RRGGBB/#RRGGBBAA? no:
 * #RRGGBB / #AARRGGBB and 0x prefixes, plus a few named colours).
 * Bare hex is intentionally rejected so the fallback path in
 * CoolUtil.colorFromString is exercised.
 */
enum abstract FlxColor(Int) from Int to Int
{
  var TRANSPARENT:FlxColor = 0x00000000;
  var BLACK:FlxColor = 0xFF000000;
  var WHITE:FlxColor = 0xFFFFFFFF;
  var RED:FlxColor = 0xFFFF0000;
  var GREEN:FlxColor = 0xFF00FF00;
  var BLUE:FlxColor = 0xFF0000FF;

  /** Parses a colour string; returns null when it is not understood. */
  public static function fromString(s:String):Null<FlxColor>
  {
    if (s == null) return null;
    final trimmed:String = StringTools.trim(s);
    switch (trimmed.toLowerCase())
    {
      case 'white': return WHITE;
      case 'black': return BLACK;
      case 'red': return RED;
      case 'green': return GREEN;
      case 'blue': return BLUE;
      case 'transparent': return TRANSPARENT;
      default:
    }
    var hex:String = trimmed;
    var hasAlpha:Bool = false;
    if (StringTools.startsWith(hex, '#'))
      hex = hex.substr(1);
    else if (StringTools.startsWith(hex, '0x') || StringTools.startsWith(hex, '0X'))
      hex = hex.substr(2);
    else
      return null; // bare hex rejected on purpose
    if (hex.length == 3)
      hex = [for (c in 0...3) hex.charAt(c) + hex.charAt(c)].join('');
    if (hex.length == 6)
      hex = 'FF' + hex; // opaque
    else if (hex.length != 8)
      return null;
    var value:Int = 0;
    for (i in 0...hex.length)
    {
      final code:Int = hex.charCodeAt(i);
      var digit:Int = -1;
      if (code >= '0'.code && code <= '9'.code) digit = code - '0'.code;
      else if (code >= 'a'.code && code <= 'f'.code) digit = code - 'a'.code + 10;
      else if (code >= 'A'.code && code <= 'F'.code) digit = code - 'A'.code + 10;
      else return null;
      value = value * 16 + digit;
    }
    return value;
  }

  /** Converts the colour to an #RRGGBB string (no alpha). */
  public inline function toHexString():String
    return '#' + StringTools.hex(this & 0xFFFFFF, 6);
}
