import backend.ClientPrefs;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.input.touch.FlxTouch;
import objects.HoldToConfirm;
import objects.TouchTarget;

/**
 * Typechecks *and* exercises the Flixel layer with renderer-free stubs.
 * Run with: bash tests/haxe/run-hold-to-confirm-typecheck.sh
 *
 * The stubs mirror the signatures used by `objects.TouchTarget` and
 * `objects.HoldToConfirm`; the pointer flags are driven by hand to prove a
 * single tap never reaches a guarded callback, the hit area is padded, and
 * both confirmation modes work with a mouse, a touch and a held key.
 */
class HoldToConfirmTypecheck
{
  static var confirmed:Int = 0;
  static var keyboardHeld:Bool = false;

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  /** Clears the guard's brief post-creation arming delay. */
  static function arm(target:TouchTarget):Void
  {
    target.update(0.2);
  }

  static function pointer(pressed:Bool, justPressed:Bool, justReleased:Bool, over:Bool):Void
  {
    FlxG.mouse.pressed = pressed;
    FlxG.mouse.justPressed = justPressed;
    FlxG.mouse.justReleased = justReleased;
    FlxG.mouse.overlapResult = over;
    FlxG.touches.list = [];
  }

  static function touch(pressed:Bool, justPressed:Bool, justReleased:Bool, over:Bool):Void
  {
    var t:FlxTouch = new FlxTouch();
    t.pressed = pressed;
    t.justPressed = justPressed;
    t.justReleased = justReleased;
    t.overlapResult = over;
    FlxG.touches.list = [t];
    FlxG.mouse.pressed = FlxG.mouse.justPressed = FlxG.mouse.justReleased = false;
    FlxG.mouse.overlapResult = false;
  }

  static function main():Void
  {
    var button:FlxSprite = new FlxSprite(500, 200);
    button.makeGraphic(80, 20);

    // Plain tap target: art unchanged, hit area enlarged to 104x88 units.
    var taps:Int = 0;
    var tapTarget:TouchTarget = new TouchTarget(button, function() taps++);
    arm(tapTarget);
    tapTarget.update(0.016);
    equal(Math.round(tapTarget.bounds.width), 104, 'padded width');
    equal(Math.round(tapTarget.bounds.height), 88, 'minimum height');
    equal(Math.round(button.width), 80, 'art width unchanged');
    equal(Math.round(button.height), 20, 'art height unchanged');
    pointer(true, true, false, true);
    tapTarget.update(0.016);
    equal(taps, 1, 'plain tap fires');
    pointer(false, false, true, false);
    tapTarget.update(0.016);
    equal(taps, 1, 'release does not re-fire');

    // Hold mode: quick tap cancels, a sustained press confirms once.
    ClientPrefs.holdToConfirm = true;
    ClientPrefs.holdToConfirmTime = 0.3;
    confirmed = 0;
    var hold:HoldToConfirm = new HoldToConfirm(button, function() confirmed++, () -> keyboardHeld);
    arm(hold);
    pointer(true, true, false, true);
    hold.update(0.016);
    equal(confirmed, 0, 'press starts a hold, not the action');
    pointer(false, false, true, false);
    hold.update(0.016);
    equal(confirmed, 0, 'quick tap cancelled');

    pointer(true, true, false, true);
    hold.update(0.016);
    pointer(true, false, false, true);
    hold.update(0.3);
    equal(confirmed, 1, 'held press confirms');
    hold.update(0.3);
    equal(confirmed, 1, 'guard is one-shot');
    check(!hold.enabled, 'guard disables itself after firing');

    // Dragging off the enlarged area cancels a hold.
    confirmed = 0;
    var drag:HoldToConfirm = new HoldToConfirm(button, function() confirmed++);
    arm(drag);
    pointer(true, true, false, true);
    drag.update(0.016);
    pointer(true, false, false, false);
    drag.update(0.016);
    equal(confirmed, 0, 'drag out cancelled');
    pointer(false, false, true, false);
    drag.update(0.016);
    pointer(true, true, false, true);
    drag.update(0.016);
    pointer(true, false, false, true);
    drag.update(0.31);
    equal(confirmed, 1, 'a fresh hold can still confirm');

    // Keyboard/gamepad hold uses the same state machine.
    confirmed = 0;
    keyboardHeld = false;
    var keys:HoldToConfirm = new HoldToConfirm(button, function() confirmed++, () -> keyboardHeld);
    arm(keys);
    pointer(false, false, false, false);
    keyboardHeld = true;
    keys.update(0.016);
    keys.update(0.3);
    equal(confirmed, 1, 'held key confirms');
    keyboardHeld = false;
    keys.update(0.016);

    // Second-confirmation mode with touch: the finger vanishes between presses.
    ClientPrefs.holdToConfirm = false;
    confirmed = 0;
    var twice:HoldToConfirm = new HoldToConfirm(button, function() confirmed++);
    arm(twice);
    touch(true, true, false, true);
    twice.update(0.016);
    equal(confirmed, 0, 'first touch only arms');
    touch(false, false, true, false);
    twice.update(0.016);
    FlxG.touches.list = [];
    twice.update(0.016);
    equal(confirmed, 0, 'no pointer between presses');
    touch(true, true, false, true);
    twice.update(0.016);
    equal(confirmed, 1, 'second touch confirms');
    twice.update(0.016);
    equal(confirmed, 1, 'one-shot in confirm mode');

    // A tap elsewhere cancels an armed second confirmation.
    confirmed = 0;
    var outside:HoldToConfirm = new HoldToConfirm(button, function() confirmed++);
    arm(outside);
    pointer(true, true, false, true);
    outside.update(0.016);
    pointer(false, false, true, false);
    outside.update(0.016);
    pointer(true, true, false, false); // fresh press on another control
    outside.update(0.016);
    pointer(false, false, true, false);
    outside.update(0.016);
    pointer(true, true, false, true);
    outside.update(0.016);
    equal(confirmed, 0, 'cancel armed, then arm again');

    // A key held from the menu that opened a guarded prompt must not arm it.
    ClientPrefs.holdToConfirm = false;
    confirmed = 0;
    keyboardHeld = true;
    var arrived:HoldToConfirm = new HoldToConfirm(button, function() confirmed++, () -> keyboardHeld);
    pointer(false, false, false, false);
    arrived.update(0.016);
    arrived.update(0.016);
    equal(confirmed, 0, 'already-held key is ignored on arrival');
    arm(arrived); // skip the rest of the arming delay
    keyboardHeld = false;
    arrived.update(0.016);
    keyboardHeld = true;
    arrived.update(0.016);
    keyboardHeld = false;
    arrived.update(0.016);
    keyboardHeld = true;
    arrived.update(0.016);
    equal(confirmed, 1, 'two fresh presses still work after the delay');
    keyboardHeld = false;

    // Row tapping uses the padded rectangle, not the original art bounds.
    FlxG.mouse.usePoint = true;
    FlxG.mouse.justPressed = true;
    FlxG.mouse.pointX = 490; // inside the 104x88 padded area...
    FlxG.mouse.pointY = 168; // ...but outside the 80x20 button art
    check(TouchTarget.justPressedOver(button, [FlxG.cameras.list[0]]),
      'tap in the padding still selects the row');
    FlxG.mouse.pointX = 510;
    FlxG.mouse.pointY = 205;
    check(TouchTarget.justPressedOver(button, [FlxG.cameras.list[0]]),
      'tap on the art selects the row');
    FlxG.mouse.pointX = 10;
    FlxG.mouse.pointY = 10;
    check(!TouchTarget.justPressedOver(button, [FlxG.cameras.list[0]]),
      'tap far away does not select the row');
    FlxG.mouse.usePoint = false;
    FlxG.mouse.justPressed = false;

    // The same padded overlap works for a finger.
    var rowTouch:FlxTouch = new FlxTouch();
    rowTouch.justPressed = true;
    rowTouch.usePoint = true;
    rowTouch.pointX = 490;
    rowTouch.pointY = 168;
    FlxG.touches.list = [rowTouch];
    check(TouchTarget.justPressedOver(button, [FlxG.cameras.list[0]]),
      'touch in the padding selects the row');
    FlxG.touches.list = [];

    trace('HoldToConfirmTypecheck passed');
  }
}
