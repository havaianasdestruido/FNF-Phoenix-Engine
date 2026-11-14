package mobile.flixel;

import flixel.FlxBasic;

enum FlxDPadMode
{
  NONE;
  UP_DOWN;
  LEFT_RIGHT;
  LEFT_FULL;
}

enum FlxActionMode
{
  NONE;
  A;
  B;
  A_B;
  A_B_C;
}

class FlxVirtualButton
{
  public var justPressed:Bool = false;
  public var pressed:Bool = false;
  public function new() {}
}

class FlxVirtualPad extends FlxBasic
{
  public var buttonA:FlxVirtualButton = new FlxVirtualButton();
  public var buttonB:FlxVirtualButton = new FlxVirtualButton();
  public var buttonC:FlxVirtualButton = new FlxVirtualButton();

  public function new(?dpad:FlxDPadMode, ?action:FlxActionMode)
  {
    super();
  }
}
