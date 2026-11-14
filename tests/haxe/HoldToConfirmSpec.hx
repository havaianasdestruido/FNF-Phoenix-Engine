import backend.HoldToConfirmLogic;
import backend.HoldToConfirmLogic.HoldInput;
import backend.HoldToConfirmLogic.HoldState;

/** Renderer-free contract tests. Run with:
 * bash tests/haxe/run-hold-to-confirm.sh
 */
class HoldToConfirmSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function input(pressed:Bool, justPressed:Bool, over:Bool,
      ?justReleased:Bool = false, ?pressedOutside:Bool = false):HoldInput
  {
    return {
      pressed: pressed,
      justPressed: justPressed,
      justReleased: justReleased,
      over: over,
      pressedOutside: pressedOutside
    };
  }

  static function main():Void
  {
    final L = HoldToConfirmLogic;

    /* ---------------------------------------------------------------- *
     * Enlarged touch targets: never smaller than 88x88 game units, and
     * always centred on the original art (which is left untouched).
     * ---------------------------------------------------------------- */
    var r = L.grow(500, 200, 80, 20);
    equal(r.width, 104, 'small button gets padding'); // 80 + 2*12, > 88
    equal(r.height, 88, 'short button reaches the minimum height');
    equal(r.x, 500 + 40 - 52, 'horizontal centring');
    equal(r.y, 200 + 10 - 44, 'vertical centring');
    check(r.x <= 500 && r.x + r.width >= 580, 'visual width is covered');
    check(r.y <= 200 && r.y + r.height >= 220, 'visual height is covered');

    r = L.grow(10, 10, 300, 140);
    equal(r.x, 10 - 12, 'wide art keeps its padding');
    equal(r.width, 324, 'wide art is not shrunk');

    r = L.grow(-5, -5, -10, -10);
    equal(r.width, L.MIN_TOUCH_SIZE, 'negative size falls back to minimum');
    equal(r.height, L.MIN_TOUCH_SIZE, 'negative height falls back to minimum');
    equal(r.x, -5 - L.MIN_TOUCH_SIZE * 0.5, 'degenerate bounds still centred');

    r = L.grow(0, 0, Math.NaN, 20, 60, 60, 0);
    equal(r.width, 60, 'NaN width collapses before the minimum is applied');
    equal(r.height, 60, 'NaN width does not corrupt height');

    equal(L.holdSeconds(null), L.DEFAULT_HOLD_SECONDS, 'missing hold time');
    equal(L.holdSeconds(Math.NaN), L.DEFAULT_HOLD_SECONDS, 'NaN hold time');
    equal(L.holdSeconds(0.01), L.DEFAULT_HOLD_SECONDS, 'too-fast hold time');
    equal(L.holdSeconds(99), L.DEFAULT_HOLD_SECONDS, 'absurd hold time');
    equal(L.holdSeconds(1.2), 1.2, 'valid hold time');
    equal(L.confirmWindow(-1), L.DEFAULT_CONFIRM_WINDOW, 'absurd confirm window');

    /* ---------------------------------------------------------------- *
     * Hold mode: a tap is never enough.
     * ---------------------------------------------------------------- */
    var s:HoldState = L.newState();
    equal(L.step(s, input(true, true, true), 0.016, L.MODE_HOLD, 0.6), L.NONE, 'press starts a hold');
    check(s.active, 'hold is active');
    equal(L.step(s, input(true, false, true), 0.5, L.MODE_HOLD, 0.6), L.NONE, 'still holding');
    check(L.progress(s, 0.6) > 0.8 && L.progress(s, 0.6) < 1, 'progress is a ratio');
    equal(L.step(s, input(true, false, true), 0.2, L.MODE_HOLD, 0.6), L.CONFIRMED, 'hold completes');
    check(s.done, 'confirmed guard latches');
    equal(L.step(s, input(true, true, true), 1, L.MODE_HOLD, 0.6), L.NONE, 'no second confirmation');
    L.reset(s);
    check(!s.done && !s.active, 'reset re-arms the guard');

    // A quick tap (press + release) must not fire.
    s = L.newState();
    equal(L.step(s, input(true, true, true), 0.016, L.MODE_HOLD, 0.6), L.NONE, 'tap starts');
    equal(L.step(s, input(false, false, true, true), 0.016, L.MODE_HOLD, 0.6), L.CANCELLED, 'tap released');
    check(!s.active && !s.done, 'tap did nothing destructive');

    // Releasing early, dragging off the target, or a zero-length frame.
    s = L.newState();
    L.step(s, input(true, true, true), 0.3, L.MODE_HOLD, 0.6);
    equal(L.step(s, input(false, false, false, true), 0.3, L.MODE_HOLD, 0.6), L.CANCELLED, 'early release cancels');
    s = L.newState();
    L.step(s, input(true, true, true), 0.3, L.MODE_HOLD, 0.6);
    equal(L.step(s, input(false, false, false), 0.3, L.MODE_HOLD, 0.6), L.CANCELLED, 'drag out cancels');
    s = L.newState();
    equal(L.step(s, input(true, true, true), 0, L.MODE_HOLD, 0.6), L.NONE, 'zero frame is harmless');
    equal(L.step(s, input(true, false, true), 0.6, L.MODE_HOLD, 0.6), L.CONFIRMED, 'frame time accumulates');

    /* ---------------------------------------------------------------- *
     * Second-confirmation mode: two distinct presses inside a window.
     * ---------------------------------------------------------------- */
    s = L.newState();
    equal(L.step(s, input(true, true, true), 0.016, L.MODE_CONFIRM), L.ARMED, 'first press arms');
    check(s.armed && s.needRelease, 'armed and waiting for a release');
    equal(L.step(s, input(true, false, true), 0.016, L.MODE_CONFIRM), L.NONE, 'same press cannot confirm');
    equal(L.step(s, input(true, true, true), 0.016, L.MODE_CONFIRM), L.NONE, 'still the same press');
    equal(L.step(s, input(false, false, false, true), 0.016, L.MODE_CONFIRM), L.NONE, 'release clears the latch');
    check(!s.needRelease, 'release is observed');
    equal(L.step(s, input(true, true, true), 0.016, L.MODE_CONFIRM), L.CONFIRMED, 'second press confirms');
    check(s.done, 'confirm mode latches too');

    // A touch vanishes on release; the armed state must survive the frame
    // where no pointer is over the target at all.
    s = L.newState();
    equal(L.step(s, input(true, true, true), 0.016, L.MODE_CONFIRM), L.ARMED, 'touch press arms');
    equal(L.step(s, input(false, false, false, true), 0.016, L.MODE_CONFIRM), L.NONE, 'touch released');
    equal(L.step(s, input(false, false, false), 0.016, L.MODE_CONFIRM), L.NONE, 'no pointer between presses');
    equal(L.step(s, input(true, true, true), 0.016, L.MODE_CONFIRM), L.CONFIRMED, 'second touch confirms');

    // Timeout and a press elsewhere cancel the armed confirmation.
    s = L.newState();
    L.step(s, input(true, true, true), 0.016, L.MODE_CONFIRM);
    equal(L.step(s, input(false, false, false, false, true), 0.016, L.MODE_CONFIRM), L.CANCELLED, 'press elsewhere cancels');
    check(!s.armed && !s.done, 'cancelled confirmation is inert');
    s = L.newState();
    L.step(s, input(true, true, true), 0.016, L.MODE_CONFIRM);
    equal(L.step(s, input(false, false, false), L.DEFAULT_CONFIRM_WINDOW + 0.1, L.MODE_CONFIRM), L.CANCELLED, 'window expires');
    equal(L.step(s, input(true, true, true), 0.016, L.MODE_CONFIRM), L.ARMED, 'expired window can be re-armed');

    /* ---------------------------------------------------------------- *
     * Merging pointer + keyboard input.
     * ---------------------------------------------------------------- */
    var pointers:HoldInput = input(false, false, false, false, true);
    var keyboard:HoldInput = input(true, true, true);
    var both:HoldInput = L.merge(pointers, keyboard);
    check(both.pressed && both.justPressed && both.over, 'keyboard press wins');
    check(!both.pressedOutside, 'a stray press cannot cancel a focused action');
    both = L.merge(pointers, input(false, false, false));
    check(both.pressedOutside, 'stray press cancels when nothing is focused');
    both = L.merge(L.idle(), L.idle());
    check(!both.pressed && !both.justPressed && !both.over, 'idle stays idle');

    /* ---------------------------------------------------------------- *
     * A JUST_PRESSED-only flag can never complete a hold. This is the
     * "Exit to game" bug: the guard was fed `controls.ACCEPT`, which
     * Controls binds as JUST_PRESSED, so every frame after the first
     * looked like a release and the progress bar restarted forever.
     * ---------------------------------------------------------------- */
    var stuck = L.newState();
    var fired:Bool = false;
    for (frame in 0...120)
    {
      // One frame of "pressed", then 119 frames of "not pressed" - what a
      // JUST_PRESSED-bound flag looks like to a per-frame sampler.
      var heldNow:Bool = frame == 0;
      var flag:HoldInput = {
        pressed: heldNow,
        justPressed: heldNow,
        justReleased: !heldNow,
        over: true,
        pressedOutside: false
      };
      var out:Int = L.step(stuck, flag, 0.016, L.MODE_HOLD, 0.65);
      if (out == L.CONFIRMED) fired = true;
    }
    check(!fired, 'a JUST_PRESSED-only flag never confirms a hold');
    equal(stuck.heldFor, 0, 'progress never accumulates across a one-frame press');

    // The PRESSED-bound twin of the same key does complete it.
    var real = L.newState();
    var confirms:Int = 0;
    for (frame in 0...120)
    {
      var heldNow:Bool = true; // ACCEPT_P stays true for the whole press
      var flag:HoldInput = {
        pressed: heldNow,
        justPressed: frame == 0,
        justReleased: false,
        over: true,
        pressedOutside: false
      };
      if (L.step(real, flag, 0.016, L.MODE_HOLD, 0.65) == L.CONFIRMED) confirms++;
    }
    equal(confirms, 1, 'a PRESSED-bound flag confirms the hold exactly once');

    trace('HoldToConfirmSpec passed');
  }
}
