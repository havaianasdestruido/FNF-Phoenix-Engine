package flixel.input;

/** Only the state enum: the page asks a pad whether a button is `PRESSED`. */
class FlxInput {}

enum abstract FlxInputState(Int) from Int
{
  var JUST_RELEASED = -1;
  var RELEASED = 0;
  var PRESSED = 1;
  var JUST_PRESSED = 2;
}
