package mobile.flixel;

import flixel.FlxSprite;

/** Mirrors the engine's `mobile.flixel.FlxVirtualPad` module: the pad plus the two
    mode enums that live in the same file (which is why `UP_DOWN`/`A_B` resolve). */
enum FlxDPadMode
{
  UP_DOWN;
  LEFT_RIGHT;
}

enum FlxActionMode
{
  A;
  B;
  A_B;
  ACCEPT;
}

class FlxVirtualPad extends FlxSprite
{
  public function new(DPad:FlxDPadMode, Action:FlxActionMode, ?Extra:Bool = false)
    super();
}
