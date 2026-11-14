package flixel.input.gamepad;

import flixel.input.FlxInput.FlxInputState;

/** A pad the spec presses by listing what is down. */
class FlxGamepad
{
  public var connected:Bool = true;

  /** Spec input: the ids that are held right now. */
  public var down:Array<FlxGamepadInputID> = [];

  /** Spec input: what this model prints on its buttons; an id left out has no label, like an unmapped one. */
  public var labels:Map<FlxGamepadInputID, String> = [A => 'a', B => 'b', X => 'x', Y => 'y', BACK => 'back', LEFT_SHOULDER => 'lb'];

  /** How often the page read a button, to prove a disconnected pad is not polled. */
  public var reads:Int = 0;

  public function new() {}

  public function checkStatus(id:FlxGamepadInputID, status:FlxInputState):Bool
  {
    reads++;
    return status == PRESSED && down.indexOf(id) != -1;
  }

  public function getInputLabel(id:FlxGamepadInputID):Null<String>
    return labels.get(id);
}
