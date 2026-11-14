import backend.InputTestLogic;
import backend.InputTestLogic.InputTestEvent;
import backend.InputTestLogic.InputNamer;

/**
 * Contract tests for `backend.InputTestLogic`, the renderer-free half of the
 * input tester (`phoenix://input`). No stubs and no game haxelibs:
 *
 *     bash tests/haxe/run-input-test.sh
 *
 * The cases follow what the page promises a player. A keyboard that drops the
 * third key of a chord has to read "held now 2", a phone that tracks two
 * fingers has to stop at two, the timing has to say how far apart presses
 * arrived and what a once-per-frame poll would have missed, and no single tap
 * may close a page whose whole point is being tapped on.
 */
class InputTestLogicSpec
{
  static inline var K:Int = InputTestLogic.KEYBOARD;
  static inline var G:Int = InputTestLogic.GAMEPAD;
  static inline var T:Int = InputTestLogic.TOUCH;

  static inline var KEY_A:Int = 65;
  static inline var KEY_D:Int = 68;
  static inline var KEY_S:Int = 83;
  static inline var KEY_ESC:Int = 27;
  static inline var KEY_BACKSPACE:Int = 8;
  static inline var PAD_A:Int = 0;
  static inline var PAD_B:Int = 1;
  static inline var PAD_X:Int = 2;

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<V>(actual:V, expected:V, label:String):Void
  {
    if (actual != expected) throw '$label: expected "$expected", got "$actual"';
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    if (Math.isNaN(actual) || Math.abs(actual - expected) > 0.000001) throw '$label: expected $expected, got $actual';
  }

  /** Names the way the page does, without needing Flixel's key tables. */
  static function name(device:Int, code:Int, slot:Int):String
  {
    return switch (device)
    {
      case InputTestLogic.KEYBOARD: code == KEY_ESC ? 'Escape' : String.fromCharCode(code);
      case InputTestLogic.GAMEPAD: 'B' + code;
      default: 'Finger ' + (slot + 1);
    }
  }

  static function main():Void
  {
    testAKeyboardThatDropsTheThirdKey();
    testAPhoneThatTracksTwoFingers();
    testCountersAcrossDevices();
    testKeyRepeatAndStrayReleases();
    testPressTiming();
    testChords();
    testWhatAFramePollWouldMiss();
    testPolledDevices();
    testDroppedInputsAreNotReleases();
    testHistory();
    testLeavingNeedsADeliberateHold();
    testLeavingIsNotBlockedByAnotherDevice();
    testText();
    testHeldNamesFitTheirPanel();
    testRevisionOnlyMovesWhenTheScreenWould();
    testBadInputIsHarmless();
    Sys.println('InputTestLogicSpec passed');
  }

  /** The headline case: three keys pressed, the keyboard only ever reports two. */
  static function testAKeyboardThatDropsTheThirdKey():Void
  {
    final logic = new InputTestLogic();
    check(logic.press(K, KEY_A, 1000), 'the first key registers');
    check(logic.press(K, KEY_S, 1004), 'the second key registers');
    // KEY_D is physically down too, but a 2-key-rollover keyboard never sends it.

    equal(logic.held(K), 2, 'the counter shows what arrived, not what was pressed');
    equal(logic.peak(K), 2, 'and so does the most-at-once figure');
    equal(logic.heldNames(K, name), 'A  S', 'the missing key is visibly missing');
    check(logic.counters(K).indexOf('held now        2') == 0, 'the panel says 2: ' + logic.counters(K));

    logic.release(K, KEY_A, 1500);
    logic.release(K, KEY_S, 1510);
    equal(logic.held(K), 0, 'letting go empties the live counter');
    equal(logic.peak(K), 2, 'the evidence stays on screen after the hands are off the keys');
    equal(logic.presses(K), 2, 'two presses were counted, not three');

    // The same keyboard on a combination it does support.
    logic.press(K, KEY_A, 2000);
    logic.press(K, KEY_S, 2001);
    logic.press(K, KEY_D, 2002);
    equal(logic.held(K), 3, 'a chord the keyboard can report reaches three');
    equal(logic.peak(K), 3, 'and raises the most-at-once figure');
  }

  /** Three fingers down on a panel that tracks two: the third is never in the list. */
  static function testAPhoneThatTracksTwoFingers():Void
  {
    final logic = new InputTestLogic();
    final firstFinger:Int = 4101;
    final secondFinger:Int = 4102;

    logic.beginPoll(T);
    equal(logic.poll(T, firstFinger, 0), 0, 'the first finger takes slot 0');
    equal(logic.poll(T, secondFinger, 0), 1, 'the second takes slot 1');
    equal(logic.endPoll(T, 0), 0, 'nothing was lifted');
    logic.endFrame();

    for (frame in 1...30)
    {
      logic.beginPoll(T);
      logic.poll(T, firstFinger, frame * 16);
      logic.poll(T, secondFinger, frame * 16);
      logic.endPoll(T, frame * 16);
      logic.endFrame();
    }
    equal(logic.held(T), 2, 'the touch counter stops at two');
    equal(logic.peak(T), 2, 'and never claims a third finger');
    equal(logic.presses(T), 2, 'holding still is not pressing again');
    equal(logic.heldNames(T, name), 'Finger 1  Finger 2', 'fingers are numbered by slot, whatever ids the OS hands out');

    // Lifting the first finger must not renumber the one still down.
    logic.beginPoll(T);
    equal(logic.poll(T, secondFinger, 500), 1, 'the remaining finger keeps its slot (and its crosshair)');
    equal(logic.endPoll(T, 500), 1, 'the lifted finger is released by the poll');
    equal(logic.held(T), 1, 'one finger left');
    near(logic.lastHold, 500, 'the lifted finger was down for the whole time');

    logic.beginPoll(T);
    logic.poll(T, secondFinger, 516);
    equal(logic.poll(T, 4200, 516), 0, 'a new finger reuses the lowest free slot');
    logic.endPoll(T, 516);
    equal(logic.heldNames(T, name), 'Finger 2  Finger 1', 'held inputs stay in press order');
  }

  static function testCountersAcrossDevices():Void
  {
    final logic = new InputTestLogic();
    logic.press(K, KEY_A, 0);
    logic.press(G, PAD_A, 1);
    logic.press(T, 7, 2);
    logic.press(K, KEY_S, 3);
    equal(logic.held(K), 2, 'keyboard count');
    equal(logic.held(G), 1, 'gamepad count');
    equal(logic.held(T), 1, 'touch count');
    equal(logic.historyAt(0).held, 4, 'an event records what was held on every device together');
    equal(logic.heldNames(K, name), 'A  S', 'a panel lists its own device only');
    equal(logic.heldNames(G, name), 'B0', 'the pad panel the pad button');
    equal(logic.heldNames(T, name), 'Finger 1', 'and a finger is Finger 1 whatever the other devices hold');

    logic.release(G, PAD_A, 10);
    logic.release(K, KEY_A, 11);
    equal(logic.held(K) + logic.held(G) + logic.held(T), 2, 'releases come off the counters');
    equal(logic.historyAt(0).held, 2, 'and off what the next event records');
    equal(logic.peak(K), 2, 'but not off the keyboard peak');
    equal(logic.peak(G), 1, 'or the gamepad peak');
    equal(logic.peak(T), 1, 'or the touch peak');

    // A later, smaller chord does not lower a peak.
    logic.release(K, KEY_S, 12);
    logic.press(K, KEY_D, 13);
    equal(logic.peak(K), 2, 'one key after two leaves the peak at two');
    equal(logic.presses(K), 3, 'presses only ever grow');
    equal(logic.presses(G) + logic.presses(T), 2, 'per device');

    // The same code on two devices is two different inputs.
    logic.press(G, KEY_D, 20);
    equal(logic.held(G), 1, 'a gamepad code equal to a held key code still registers');
    equal(logic.held(K), 1, 'next to the key, not instead of it');
    near(logic.release(G, KEY_D, 30), 10, 'and is released on its own');
    equal(logic.held(K), 1, 'which leaves the key held');
  }

  static function testKeyRepeatAndStrayReleases():Void
  {
    final logic = new InputTestLogic();
    check(logic.press(K, KEY_A, 0), 'first press');
    // The OS repeats a held key about 30 times a second.
    for (repeat in 1...40)
      check(!logic.press(K, KEY_A, repeat * 33), 'a repeat is not a press');
    equal(logic.presses(K), 1, 'forty key-down events, one press');
    equal(logic.held(K), 1, 'and one held key');
    near(logic.lastGap, InputTestLogic.NONE, 'repeats do not invent a gap');

    near(logic.release(K, KEY_A, 1320), 1320, 'the hold is measured from the real press, not the last repeat');
    near(logic.release(K, KEY_A, 1321), InputTestLogic.NONE, 'a second release reports nothing');
    near(logic.release(K, KEY_D, 1400), InputTestLogic.NONE, 'a key that went down before the page opened is ignored');
    equal(logic.held(K), 0, 'stray releases cannot push the counter below zero');
    equal(logic.historyLength(), 2, 'and they leave no trace in the history');
  }

  static function testPressTiming():Void
  {
    final logic = new InputTestLogic();
    near(logic.lastGap, InputTestLogic.NONE, 'no gap before any press');
    near(logic.lastHold, InputTestLogic.NONE, 'no hold before any release');

    logic.press(K, KEY_A, 5000);
    near(logic.lastGap, InputTestLogic.NONE, 'a first press has nothing to be compared with');
    logic.press(K, KEY_S, 5012.5);
    near(logic.lastGap, 12.5, 'the gap is press to press');
    logic.press(G, PAD_A, 5012.5);
    near(logic.lastGap, 0, 'two inputs read in the same poll arrive together');
    logic.release(K, KEY_A, 5100);
    near(logic.lastHold, 100, 'a hold is press to release of the same input');
    near(logic.lastGap, 0, 'a release does not disturb the press gap');

    // Gaps are measured across devices and across releases.
    logic.release(K, KEY_S, 5200);
    logic.release(G, PAD_A, 5200);
    logic.press(T, 1, 5300);
    near(logic.lastGap, 287.5, 'the gap spans devices: it is about arrival order');

    // A clock that steps backwards must not produce negative durations.
    logic.press(K, KEY_D, 5290);
    near(logic.lastGap, 0, 'an earlier timestamp clamps to zero instead of going negative');
    near(logic.release(K, KEY_D, 5280), 0, 'and so does a hold');

    // A clock that hiccups once must not poison what follows.
    logic.press(K, KEY_A, Math.NaN);
    check(!Math.isNaN(logic.lastGap), 'a NaN timestamp falls back to the last good one');
    logic.press(K, KEY_S, 5400);
    near(logic.lastGap, 120, 'and the next real timestamp is measured from it');
  }

  static function testChords():Void
  {
    final logic = new InputTestLogic();
    equal(logic.chordSize, 0, 'no chord yet');

    logic.press(K, KEY_A, 100);
    equal(logic.chordSize, 1, 'one key is a chord of one');
    near(logic.chordSpread, 0, 'with no spread');
    logic.press(K, KEY_S, 103);
    logic.press(K, KEY_D, 109.5);
    equal(logic.chordSize, 3, 'three keys held together');
    near(logic.chordSpread, 9.5, 'built in the time from the first press to the third');

    // Re-pressing one key of the chord does not make it "bigger" or "slower".
    logic.release(K, KEY_D, 400);
    logic.press(K, KEY_D, 900);
    equal(logic.chordSize, 3, 'the chord stays three');
    near(logic.chordSpread, 9.5, 'and keeps the time it took to reach three');

    // The reading survives letting go, so it can be read with the hands off.
    logic.release(K, KEY_A, 1000);
    logic.release(K, KEY_S, 1000);
    logic.release(K, KEY_D, 1000);
    equal(logic.chordSize, 3, 'the last chord is still shown after the release');

    // The next press starts over.
    logic.press(G, PAD_A, 2000);
    logic.press(G, PAD_B, 2016);
    equal(logic.chordSize, 2, 'a new chord replaces the old one');
    near(logic.chordSpread, 16, 'two pad buttons one frame apart');
  }

  /** TODO.md §15: what a 60 Hz poll does to a 1000 Hz keyboard. */
  static function testWhatAFramePollWouldMiss():Void
  {
    final logic = new InputTestLogic();
    equal(logic.maxFramePresses, 0, 'nothing pressed yet');

    // Frame 1: one press.
    logic.press(K, KEY_A, 0);
    equal(logic.framePresses, 1, 'one press so far this frame');
    logic.endFrame();
    equal(logic.framePresses, 0, 'the frame counter starts over');
    equal(logic.maxFramePresses, 1, 'the record is kept');

    // Frame 2: three presses one millisecond apart, all before the next update.
    logic.press(K, KEY_S, 17);
    logic.press(K, KEY_D, 18);
    logic.press(G, PAD_A, 19);
    equal(logic.maxFramePresses, 3, 'three presses landed inside one frame');
    logic.endFrame();

    // Frame 3: nothing new.
    logic.endFrame();
    equal(logic.maxFramePresses, 3, 'an empty frame does not lower the record');
    equal(logic.shortTaps, 0, 'everything so far was held across a frame boundary');

    // A tap that is over before the frame ends: a poll never sees it held.
    logic.release(K, KEY_A, 50);
    logic.press(K, KEY_A, 51);
    equal(logic.maxFramePresses, 3, 'a quieter frame does not lower the record either');
    logic.release(K, KEY_A, 54);
    equal(logic.shortTaps, 1, 'down and up inside one frame is a short tap');
    logic.endFrame();

    // The same 3 ms tap straddling a frame boundary is visible to a poll.
    logic.press(K, KEY_A, 66);
    logic.endFrame();
    logic.release(K, KEY_A, 69);
    equal(logic.shortTaps, 1, 'a tap that crosses the boundary is not short');

    // Releasing a long hold in the frame it started in is impossible; releasing
    // it many frames later must not count either.
    logic.endFrame();
    logic.release(K, KEY_S, 100);
    equal(logic.shortTaps, 1, 'long holds never count as short taps');
  }

  static function testPolledDevices():Void
  {
    final logic = new InputTestLogic();

    // A button that is simply held produces one press, however often it is read.
    for (frame in 0...10)
    {
      logic.beginPoll(G);
      equal(logic.poll(G, PAD_A, frame * 16), 0, 'the held button keeps slot 0');
      equal(logic.endPoll(G, frame * 16), 0, 'and is not released');
      logic.endFrame();
    }
    equal(logic.presses(G), 1, 'ten reads, one press');

    // A second button joins, then the first is let go.
    logic.beginPoll(G);
    logic.poll(G, PAD_A, 160);
    logic.poll(G, PAD_B, 160);
    logic.endPoll(G, 160);
    equal(logic.held(G), 2, 'two buttons');
    near(logic.lastGap, 160, 'the second press is timed by the poll that saw it');

    logic.beginPoll(G);
    logic.poll(G, PAD_B, 176);
    equal(logic.endPoll(G, 176), 1, 'the button missing from the poll is released');
    equal(logic.heldNames(G, name), 'B' + PAD_B, 'the right one');
    near(logic.lastHold, 176, 'held from the first poll that saw it to the first that did not');

    // Polling one device leaves the others alone: keys are event driven.
    logic.press(K, KEY_A, 180);
    logic.beginPoll(G);
    equal(logic.endPoll(G, 192), 1, 'an empty gamepad poll releases the gamepad buttons');
    equal(logic.held(K), 1, 'and does not touch the keyboard');
    logic.beginPoll(T);
    logic.endPoll(T, 192);
    equal(logic.held(K), 1, 'neither does a touch poll');

    // Frames can be skipped (a hitch, a paused update): the diff still holds.
    logic.beginPoll(G);
    logic.poll(G, PAD_X, 1000);
    logic.endPoll(G, 1000);
    logic.beginPoll(G);
    logic.poll(G, PAD_X, 4000);
    logic.endPoll(G, 4000);
    equal(logic.presses(G), 3, 'a skipped frame does not turn a hold into a new press');

    // A poll never reports the same input twice as two presses.
    logic.beginPoll(G);
    logic.poll(G, PAD_X, 4016);
    logic.poll(G, PAD_X, 4016);
    logic.endPoll(G, 4016);
    equal(logic.held(G), 1, 'one button reported twice is still one button');

    // Two devices may be read in one go: each poll only speaks for its own.
    final both = new InputTestLogic();
    both.beginPoll(G);
    both.beginPoll(T);
    both.poll(G, PAD_A, 0);
    both.poll(T, 1, 0);
    equal(both.endPoll(G, 0) + both.endPoll(T, 0), 0, 'nothing to release yet');
    both.beginPoll(G);
    both.poll(G, PAD_A, 16);
    both.beginPoll(T);
    both.poll(T, 1, 16);
    equal(both.endPoll(G, 16), 0, 'starting the touch poll does not make the pad forget its button');
    equal(both.endPoll(T, 16), 0, 'and the finger is still down');
    both.beginPoll(G);
    both.beginPoll(T);
    both.poll(G, PAD_A, 32);
    equal(both.endPoll(G, 32), 0, 'ending the pad poll does not release a finger');
    equal(both.held(T), 1, 'the finger waits for its own poll to end');
    equal(both.endPoll(T, 32), 1, 'which then releases it');
  }

  /** Focus loss: the releases will never arrive, so they must not be invented. */
  static function testDroppedInputsAreNotReleases():Void
  {
    final logic = new InputTestLogic();
    logic.press(K, KEY_A, 0);
    logic.press(K, KEY_S, 5);
    logic.press(G, PAD_A, 6);
    logic.release(K, KEY_S, 40);
    final holdBefore:Float = logic.lastHold;
    final historyBefore:Int = logic.historyLength();

    equal(logic.drop(), 2, 'the key and the button that were still down are forgotten');
    equal(logic.held(K) + logic.held(G), 0, 'nothing is held any more');
    equal(logic.heldNames(K, name) + logic.heldNames(G, name), '', 'or named');
    near(logic.lastHold, holdBefore, 'no hold time was made up');
    equal(logic.historyLength(), historyBefore, 'and no release was logged');
    equal(logic.peak(K), 2, 'peaks are facts and stay');
    equal(logic.drop(), 0, 'dropping nothing is a no-op');

    // The key can be pressed again afterwards, as a new press.
    check(logic.press(K, KEY_A, 9000), 'a dropped key registers again');
    equal(logic.chordSize, 1, 'as the start of a new chord');
    near(logic.release(K, KEY_A, 9010), 10, 'with its own hold time');
  }

  static function testHistory():Void
  {
    final logic = new InputTestLogic(4);
    equal(logic.historyLength(), 0, 'empty history');
    check(logic.historyAt(0) == null, 'nothing to read yet');

    logic.press(K, KEY_A, 0);
    logic.press(K, KEY_S, 8);
    logic.release(K, KEY_A, 90);

    equal(logic.historyLength(), 3, 'three events');
    var event:InputTestEvent = logic.historyAt(0);
    check(!event.down && event.code == KEY_A, 'index 0 is the most recent event');
    near(event.span, 90, 'a release carries its hold');
    equal(event.held, 1, 'and how many were still held afterwards');

    event = logic.historyAt(1);
    check(event.down && event.code == KEY_S, 'then the press before it');
    near(event.span, 8, 'a press carries the gap to the previous press');
    equal(event.held, 2, 'and how many were held with it');

    event = logic.historyAt(2);
    check(event.down && event.code == KEY_A, 'then the first press');
    near(event.span, InputTestLogic.NONE, 'which has no gap');
    check(logic.historyAt(3) == null && logic.historyAt(-1) == null, 'out of range reads are null, not garbage');

    // A full history forgets the oldest event first.
    logic.release(K, KEY_S, 100);
    logic.press(G, PAD_B, 120);
    logic.release(G, PAD_B, 150);
    equal(logic.historyLength(), 4, 'the history is bounded');
    check(logic.historyAt(0).device == G && !logic.historyAt(0).down, 'newest: the pad release');
    check(logic.historyAt(3).code == KEY_A && !logic.historyAt(3).down, 'oldest kept: the key release; both early presses are gone');

    // Slots are frozen into the event, so a finger keeps its name after it lifts.
    final touches = new InputTestLogic();
    touches.press(T, 900, 0);
    touches.press(T, 901, 1);
    touches.release(T, 901, 2);
    touches.press(T, 902, 3);
    equal(touches.history(name).split('\n')[1].indexOf('up    Finger 2'), 0, 'the lifted finger is still called Finger 2');
    equal(touches.history(name).split('\n')[0].indexOf('down  Finger 2'), 0, 'and the new one took over that slot');
  }

  /** Every input is a test subject, so only a deliberate, lonely hold leaves. */
  static function testLeavingNeedsADeliberateHold():Void
  {
    final frame:Float = 1 / 60;
    var logic = new InputTestLogic();
    check(!logic.updateExit(frame), 'nothing held, nothing happens');
    near(logic.exitProgress(), 0, 'no progress either');

    // Tapping Escape: it must show up as a key, not close the page.
    logic.press(K, KEY_ESC, 0, true);
    for (step in 0...5)
      check(!logic.updateExit(frame), 'a short press of Escape is just a key');
    check(logic.exitProgress() > 0 && logic.exitProgress() < 1, 'the bar has started to fill');
    logic.release(K, KEY_ESC, 80);
    check(!logic.updateExit(frame), 'released early');
    near(logic.exitProgress(), 0, 'letting go empties the bar');

    // Holding it: leaves once, after the full second.
    logic.press(K, KEY_ESC, 1000, true);
    var frames:Int = 0;
    var left:Bool = false;
    while (!left && frames < 600)
    {
      left = logic.updateExit(frame);
      frames++;
    }
    check(left, 'a held Escape leaves');
    check(frames >= 59 && frames <= 61, 'after one second, not sooner: ' + frames + ' frames');
    near(logic.exitProgress(), 1, 'the bar is full');
    for (step in 0...120)
      check(!logic.updateExit(frame), 'and the page is asked to close exactly once');

    // A chord that happens to contain an exit input must not throw the player out.
    logic = new InputTestLogic();
    logic.press(G, PAD_A, 0);
    logic.press(G, PAD_B, 2, true);
    logic.press(G, PAD_X, 4);
    for (step in 0...300)
      check(!logic.updateExit(frame), 'A+B+X held for five seconds is a rollover test, not a goodbye');
    near(logic.exitProgress(), 0, 'no progress while other buttons are down');

    // Letting the others go turns it into a real hold, from zero.
    logic.release(G, PAD_A, 5000);
    logic.release(G, PAD_X, 5000);
    check(!logic.updateExit(frame), 'the hold only starts now');
    check(logic.exitProgress() < 0.1, 'from the beginning');

    // Pressing something else during the hold starts it over.
    for (step in 0...30)
      logic.updateExit(frame);
    check(logic.exitProgress() > 0.4, 'half way there');
    logic.press(G, PAD_X, 6000);
    check(!logic.updateExit(frame), 'another button interrupts');
    near(logic.exitProgress(), 0, 'and resets the bar');

    // Two Back keys together are still nothing but Back.
    logic = new InputTestLogic();
    logic.press(K, KEY_ESC, 0, true);
    logic.press(K, KEY_BACKSPACE, 1, true);
    left = false;
    for (step in 0...61)
      left = logic.updateExit(frame) || left;
    check(left, 'Escape and Backspace held together leave too');

    // The hold is counted in game time, and a broken frame time cannot shorten it.
    logic = new InputTestLogic();
    logic.press(K, KEY_ESC, 0, true);
    check(!logic.updateExit(0.9), 'nine tenths of a second is not enough');
    near(logic.exitProgress(), 0.9, 'the bar shows nine tenths');
    check(!logic.updateExit(Math.NaN), 'a NaN frame adds nothing');
    check(!logic.updateExit(-5), 'a negative frame adds nothing');
    near(logic.exitProgress(), 0.9, 'and does not rewind the hold either');
    check(logic.updateExit(0.2), 'the last tenth closes the page');
    near(logic.exitProgress(), 1, 'with a bar that never overshoots');
  }

  static function testLeavingIsNotBlockedByAnotherDevice():Void
  {
    final frame:Float = 1 / 60;

    // A drifting stick is a gamepad input that never goes away. The keyboard
    // must still be able to leave.
    var logic = new InputTestLogic();
    logic.press(G, 35, 0);
    logic.press(K, KEY_ESC, 10, true);
    var left:Bool = false;
    for (step in 0...61)
      left = logic.updateExit(frame) || left;
    check(left, 'a stuck gamepad input does not block the keyboard');

    // ...but that gamepad cannot leave by itself while the stick is "held".
    logic = new InputTestLogic();
    logic.press(G, 35, 0);
    logic.press(G, PAD_B, 10, true);
    for (step in 0...300)
      check(!logic.updateExit(frame), 'B plus a stuck stick is not B alone');

    // A finger on EXIT while other fingers are down: a multi-touch test.
    logic = new InputTestLogic();
    logic.beginPoll(T);
    logic.poll(T, 1, 0, true);
    logic.poll(T, 2, 0);
    logic.poll(T, 3, 0);
    logic.endPoll(T, 0);
    for (step in 0...300)
      check(!logic.updateExit(frame), 'three fingers, one of them on EXIT, stay on the page');

    // The same finger alone is the gesture.
    logic.beginPoll(T);
    logic.poll(T, 1, 5000, true);
    logic.endPoll(T, 5000);
    left = false;
    for (step in 0...61)
      left = logic.updateExit(frame) || left;
    check(left, 'one finger held on EXIT leaves');

    // The exit flag belongs to the press: a finger that started elsewhere and
    // is later reported "on EXIT" was not aimed at it.
    logic = new InputTestLogic();
    logic.beginPoll(T);
    logic.poll(T, 1, 0, false);
    logic.endPoll(T, 0);
    for (step in 0...120)
    {
      logic.beginPoll(T);
      logic.poll(T, 1, 16 + step * 16, true);
      logic.endPoll(T, 16 + step * 16);
      check(!logic.updateExit(frame), 'sliding onto EXIT does not start the gesture');
    }

    // A mouse is not a tracked device; the page reports it as a pointer. It is
    // the way out when a key is stuck down.
    logic = new InputTestLogic();
    logic.press(K, KEY_A, 0);
    left = false;
    for (step in 0...61)
      left = logic.updateExit(frame, true) || left;
    check(left, 'the mouse on EXIT leaves even with a key held');

    logic = new InputTestLogic();
    for (step in 0...30)
      logic.updateExit(frame, true);
    check(logic.exitProgress() > 0.4, 'the pointer fills the bar');
    logic.updateExit(frame, false);
    near(logic.exitProgress(), 0, 'and releasing it empties the bar');
  }

  static function testText():Void
  {
    equal(InputTestLogic.formatMs(12.44), '12.4 ms', 'one decimal');
    equal(InputTestLogic.formatMs(12.46), '12.5 ms', 'rounded, not cut');
    equal(InputTestLogic.formatMs(0), '0.0 ms', 'zero keeps its decimal so the column stays aligned');
    equal(InputTestLogic.formatMs(0.04), '0.0 ms', 'inputs that arrived together read as zero');
    equal(InputTestLogic.formatMs(999.96), '1000.0 ms', 'rounding may carry');
    equal(InputTestLogic.formatMs(9999.94), '9999.9 ms', 'milliseconds up to ten seconds');
    equal(InputTestLogic.formatMs(9999.95), '10.0 s', 'then seconds, without a five digit jump first');
    equal(InputTestLogic.formatMs(84260), '84.3 s', 'long holds in seconds');
    equal(InputTestLogic.formatMs(InputTestLogic.NONE), '-', 'no value');
    equal(InputTestLogic.formatMs(Math.NaN), '-', 'NaN is no value');
    equal(InputTestLogic.formatMs(Math.POSITIVE_INFINITY), '-', 'infinity is no value');
    equal(InputTestLogic.formatMs(99999999949.0), '99999999.9 s', 'three years still format');
    equal(InputTestLogic.formatMs(1e11), '-', 'past that a reading can only be a clock glitch, and is not shown');
    equal(InputTestLogic.formatMs(1e15), '-', 'however large');

    equal(InputTestLogic.deviceName(K), 'KEYBOARD', 'keyboard title');
    equal(InputTestLogic.deviceName(G), 'GAMEPAD', 'gamepad title');
    equal(InputTestLogic.deviceName(T), 'TOUCH', 'touch title');
    equal(InputTestLogic.deviceName(7), 'UNKNOWN', 'unknown device title');

    final logic = new InputTestLogic();
    equal(logic.counters(K), 'held now        0\nmost at once    0\npresses         0', 'an untouched device');
    equal(logic.heldNames(K, name), '', 'nothing held, nothing named');
    equal(logic.timing(name), [
      'last press     -',
      'last release   -',
      'last chord     -',
      'most per frame 0 presses in one frame',
      'short taps     0 down and up inside one frame'
    ].join('\n'), 'the timing panel before any input');
    equal(logic.history(name), '', 'an empty history is empty text');

    logic.press(K, KEY_A, 0);
    check(logic.timing(name).indexOf('last press     A  (first press)\n') == 0, 'a first press says so: ' + logic.timing(name));
    check(logic.timing(name).indexOf('last chord     1 at once\n') > 0, 'a chord of one has no build time');
    check(logic.timing(name).indexOf('most per frame 1 press in one frame') > 0, 'singular press');
    logic.endFrame();
    logic.press(K, KEY_S, 12.4);
    logic.press(K, KEY_D, 14);
    logic.endFrame();
    logic.release(K, KEY_A, 96.4);

    equal(logic.counters(K), 'held now        2\nmost at once    3\npresses         3', 'the columns line up');

    // Three different numbers, so a row that shows the wrong counter is caught.
    final rows = new InputTestLogic();
    rows.press(K, KEY_A, 0);
    rows.release(K, KEY_A, 10);
    rows.press(K, KEY_A, 20);
    rows.press(K, KEY_S, 30);
    rows.release(K, KEY_S, 40);
    equal(rows.counters(K), 'held now        1\nmost at once    2\npresses         3', 'each row shows its own counter');
    equal(logic.heldNames(K, name), 'S  D', 'held keys in press order');
    equal(logic.heldNames(K, name, 0, 1, ' + '), 'S + D', 'with the separator asked for');
    equal(logic.timing(name, 1000 / 60), [
      'last press     D  +1.6 ms',
      'last release   A  held 96.4 ms',
      'last chord     3 at once, built in 14.0 ms',
      'most per frame 2 presses in one frame (16.7 ms)',
      'short taps     0 down and up inside one frame'
    ].join('\n'), 'the timing panel');
    check(logic.timing(name, Math.NaN).indexOf('(') == -1 && logic.timing(name, -3).indexOf('(') == -1,
      'an unknown frame length is left out, not printed as nonsense');
    equal(logic.history(name), [
      'up    A            held 96.4 ms',
      'down  D            +1.6 ms     3 held',
      'down  S            +12.4 ms    2 held',
      'down  A            first       1 held'
    ].join('\n'), 'the history, newest first');
  }

  /** A device panel is so many characters wide and so many lines tall, whatever is held. */
  static function testHeldNamesFitTheirPanel():Void
  {
    final keys = new InputTestLogic();
    for (key in 0...26)
      keys.press(K, KEY_A + key, key);
    equal(keys.held(K), 26, 'all twenty-six keys count');

    equal(keys.heldNames(K, name, 30, 3), 'A  B  C  D  E  F  G  H  I  J\nK  L  M  N  O  P  Q  R  S  T\nU  V  W  X  Y  Z',
      'three lines of thirty characters hold the alphabet');
    equal(keys.heldNames(K, name, 30, 2), 'A  B  C  D  E  F  G  H  I  J\nK  L  M  N  O  P  Q  +9 more', 'two lines do not, so the rest is summed up');
    equal(keys.heldNames(K, name, 30, 1), 'A  B  C  D  E  F  G  +19 more', 'one line shows what fits beside the summary');
    equal(keys.heldNames(K, name, 28, 1), 'A  B  C  D  E  F  +20 more', 'a narrower line shows one name less');
    equal(keys.heldNames(K, name, 0, 1).split('  ').length, 26, 'without a width everything goes on one line');
    equal(keys.heldNames(K, name), keys.heldNames(K, name, -5, 9), 'and the line count is ignored');
    equal(keys.heldNames(K, name, 4, 2), 'A  B\n+24 more', 'the summary may take the last line alone');
    equal(keys.heldNames(K, name, 30, 0), keys.heldNames(K, name, 30, 1), 'there is always one line: the panel has to say something');
    equal(keys.heldNames(K, name, 7, 1), '+26 more', 'no room for a single name beside the summary leaves the count');
    equal(keys.heldNames(G, name, 30, 3), '', 'nothing held on the other device, nothing listed');

    // Names of different lengths, every panel size: the promise holds for all of them.
    final uneven:InputNamer = (device, code, slot) -> StringTools.rpad('', 'x', 1 + (code * 5) % 9);
    for (columns in 6...41)
    {
      for (rows in 1...5)
      {
        final lines:Array<String> = keys.heldNames(K, uneven, columns, rows).split('\n');
        check(lines.length <= rows, 'never more than $rows lines at $columns columns');
        var listed:Int = 0;
        var summed:Int = 0;
        for (line in lines)
        {
          final pieces:Array<String> = line.split('  ');
          check(line.length <= columns || pieces.length == 1, 'a line of $columns columns is not overrun: "$line"');
          for (piece in pieces)
          {
            if (piece.charAt(0) == '+') summed = Std.parseInt(piece.substr(1));
            else
              listed++;
          }
        }
        equal(listed + summed, 26, 'every held key is either named or counted ($columns x $rows)');
      }
    }

    // Two long names side by side use the line to its last character.
    final unnamed = new InputTestLogic();
    unnamed.press(K, 1001, 0);
    unnamed.press(K, 1002, 1);
    unnamed.press(K, 1003, 2);
    final byCode:InputNamer = (device, code, slot) -> 'Key 100000' + code;
    equal(unnamed.heldNames(K, byCode, 30, 3), 'Key 1000001001  Key 1000001002\nKey 1000001003', 'a line may be filled exactly');
    equal(unnamed.heldNames(K, byCode, 29, 3), 'Key 1000001001\nKey 1000001002\nKey 1000001003', 'and not by one character more');

    // A name wider than the panel cannot be made to fit; it still gets its own line.
    equal(unnamed.heldNames(K, byCode, 5, 3), 'Key 1000001001\nKey 1000001002\nKey 1000001003', 'over-long names are not dropped');
    equal(unnamed.heldNames(K, byCode, 5, 2), 'Key 1000001001\n+2 more', 'while there are lines left for them');
  }

  static function testRevisionOnlyMovesWhenTheScreenWould():Void
  {
    final logic = new InputTestLogic();
    var seen:Int = logic.revision;

    logic.endFrame();
    logic.updateExit(0.016);
    logic.beginPoll(G);
    logic.endPoll(G, 0);
    logic.drop();
    logic.release(K, KEY_A, 0);
    equal(logic.revision, seen, 'idle frames redraw nothing');

    logic.press(K, KEY_A, 0);
    check(logic.revision != seen, 'a press redraws');
    seen = logic.revision;

    logic.press(K, KEY_A, 33);
    equal(logic.revision, seen, 'key repeat does not');

    logic.beginPoll(G);
    logic.poll(G, PAD_A, 40);
    logic.endPoll(G, 40);
    check(logic.revision != seen, 'a polled press redraws');
    seen = logic.revision;

    for (frame in 0...5)
    {
      logic.beginPoll(G);
      logic.poll(G, PAD_A, 56 + frame * 16);
      logic.endPoll(G, 56 + frame * 16);
      logic.endFrame();
    }
    equal(logic.revision, seen, 'a held button does not redraw every frame');

    logic.release(K, KEY_A, 200);
    check(logic.revision != seen, 'a release redraws');
    seen = logic.revision;

    logic.drop();
    check(logic.revision != seen, 'dropping held inputs redraws');
  }

  static function testBadInputIsHarmless():Void
  {
    final logic = new InputTestLogic(0);
    check(!logic.press(-1, 1, 0), 'a negative device is refused');
    check(!logic.press(InputTestLogic.DEVICES, 1, 0), 'a device past the last one is refused');
    near(logic.release(9, 1, 0), InputTestLogic.NONE, 'releasing on an unknown device does nothing');
    equal(logic.poll(-3, 1, 0), -1, 'polling an unknown device has no slot');
    logic.beginPoll(42);
    equal(logic.endPoll(42, 0), 0, 'and releases nothing');
    equal(logic.held(-1) + logic.peak(9) + logic.presses(-7), 0, 'counters of unknown devices are zero');
    equal(logic.heldNames(11, name), '', 'nothing is listed for an unknown device');
    equal(logic.held(K) + logic.held(G) + logic.held(T), 0, 'none of it reached a real device');
    equal(logic.historyLength(), 0, 'or the history');
    equal(logic.revision, 0, 'or the screen');

    // A history size below one still keeps the latest event instead of crashing.
    logic.press(K, KEY_A, 0);
    logic.press(K, KEY_S, 1);
    equal(logic.historyLength(), 1, 'a history of zero is treated as one');
    equal(logic.historyAt(0).code, KEY_S, 'holding the most recent event');

    // Codes are opaque: negative and huge ones are inputs like any other.
    check(logic.press(K, -40000, 2), 'a negative code is accepted');
    check(logic.press(K, 0x4000010E, 3), 'so is a code above the key tables');
    equal(logic.held(K), 4, 'both count');
    near(logic.release(K, -40000, 5), 3, 'and release normally');
  }
}
