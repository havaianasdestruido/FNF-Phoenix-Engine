package objects;

import flixel.FlxObject;

class HoldToConfirm extends TouchTarget
{
  public var onConfirm:Void->Void;
  public var held:Void->Bool;
  public var hint:String;
  public var cancelled:Int = 0;

  public function new(?target:FlxObject, ?onConfirm:Void->Void, ?held:Void->Bool, ?hint:String = 'HOLD TO CONFIRM')
  {
    super(target, null);
    this.onConfirm = onConfirm;
    this.held = held;
    this.hint = hint;
  }

  public function cancel():Void
  {
    cancelled++;
  }
}
