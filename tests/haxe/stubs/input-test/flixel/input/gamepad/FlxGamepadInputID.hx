package flixel.input.gamepad;

/**
 * Flixel's gamepad input ids with their real values and names: the page packs
 * a pad index and one of these into a single input code, so the numbers have
 * to be the ones the real enum uses.
 */
enum abstract FlxGamepadInputID(Int) from Int to Int
{
  var ANY = -2;
  var NONE = -1;
  var A = 0;
  var B = 1;
  var X = 2;
  var Y = 3;
  var LEFT_SHOULDER = 4;
  var RIGHT_SHOULDER = 5;
  var BACK = 6;
  var START = 7;
  var LEFT_STICK_CLICK = 8;
  var RIGHT_STICK_CLICK = 9;
  var GUIDE = 10;
  var DPAD_UP = 11;
  var DPAD_DOWN = 12;
  var DPAD_LEFT = 13;
  var DPAD_RIGHT = 14;
  var LEFT_TRIGGER_BUTTON = 15;
  var RIGHT_TRIGGER_BUTTON = 16;
  var LEFT_TRIGGER = 17;
  var RIGHT_TRIGGER = 18;
  var LEFT_ANALOG_STICK = 19;
  var RIGHT_ANALOG_STICK = 20;
  var DPAD = 21;
  var TILT_PITCH = 26;
  var TILT_ROLL = 27;
  var POINTER_X = 28;
  var POINTER_Y = 29;
  var EXTRA_0 = 30;
  var EXTRA_1 = 31;
  var EXTRA_2 = 32;
  var EXTRA_3 = 33;
  var LEFT_STICK_DIGITAL_UP = 34;
  var LEFT_STICK_DIGITAL_RIGHT = 35;
  var LEFT_STICK_DIGITAL_DOWN = 36;
  var LEFT_STICK_DIGITAL_LEFT = 37;
  var RIGHT_STICK_DIGITAL_UP = 38;
  var RIGHT_STICK_DIGITAL_RIGHT = 39;
  var RIGHT_STICK_DIGITAL_DOWN = 40;
  var RIGHT_STICK_DIGITAL_LEFT = 41;
  var ACCEPT = 42;
  var CANCEL = 43;

  static final names:Map<Int, String> = [
    -2 => 'ANY',
    -1 => 'NONE',
    0 => 'A',
    1 => 'B',
    2 => 'X',
    3 => 'Y',
    4 => 'LEFT_SHOULDER',
    5 => 'RIGHT_SHOULDER',
    6 => 'BACK',
    7 => 'START',
    8 => 'LEFT_STICK_CLICK',
    9 => 'RIGHT_STICK_CLICK',
    10 => 'GUIDE',
    11 => 'DPAD_UP',
    12 => 'DPAD_DOWN',
    13 => 'DPAD_LEFT',
    14 => 'DPAD_RIGHT',
    15 => 'LEFT_TRIGGER_BUTTON',
    16 => 'RIGHT_TRIGGER_BUTTON',
    17 => 'LEFT_TRIGGER',
    18 => 'RIGHT_TRIGGER',
    19 => 'LEFT_ANALOG_STICK',
    20 => 'RIGHT_ANALOG_STICK',
    21 => 'DPAD',
    26 => 'TILT_PITCH',
    27 => 'TILT_ROLL',
    28 => 'POINTER_X',
    29 => 'POINTER_Y',
    30 => 'EXTRA_0',
    31 => 'EXTRA_1',
    32 => 'EXTRA_2',
    33 => 'EXTRA_3',
    34 => 'LEFT_STICK_DIGITAL_UP',
    35 => 'LEFT_STICK_DIGITAL_RIGHT',
    36 => 'LEFT_STICK_DIGITAL_DOWN',
    37 => 'LEFT_STICK_DIGITAL_LEFT',
    38 => 'RIGHT_STICK_DIGITAL_UP',
    39 => 'RIGHT_STICK_DIGITAL_RIGHT',
    40 => 'RIGHT_STICK_DIGITAL_DOWN',
    41 => 'RIGHT_STICK_DIGITAL_LEFT',
    42 => 'ACCEPT',
    43 => 'CANCEL'
  ];

  /** `null` for a code without a name, like the real `toStringMap.get(this)`. */
  @:to
  public inline function toString():String
    return names.get(this);
}
