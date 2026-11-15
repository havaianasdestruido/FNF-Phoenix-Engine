import backend.ClientPrefs;
import backend.HardwareKeys;
import backend.InputTestLogic;
import backend.MusicBeatState;
import backend.ViewportVisuals;
import flixel.FlxG;
import flixel.FlxG.FlxTouch;
import flixel.FlxSprite;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.keyboard.FlxKey;
import flixel.text.FlxText;
import mobile.MobileControls;
import openfl.events.KeyboardEvent;
import states.InputTestState;
import states.TitleState;

/**
 * Drives the real `states/InputTestState.hx` (the page behind `phoenix://input`)
 * in the Haxe interpreter: a keyboard that sends stage key events, pads that
 * are polled, fingers in `FlxG.touches.list`, a mouse, and a scripted clock.
 * `backend.InputTestLogic`, `InputFormatter`, `HardwareKeys`, `ScreenLayout`,
 * `HoldToConfirmLogic`, `TouchlessUI` and `AndroidTVPolicy` are the production
 * files; only Flixel, OpenFL and the engine's heavy singletons are stubs
 * (tests/haxe/stubs/input-test).
 *
 *     bash tests/haxe/run-input-test.sh
 *
 * The counting itself is specified in InputTestLogicSpec. This file is about
 * the wiring a player would notice if it broke: the page must show what was
 * pressed, must not be closed by pressing things, must hand the volume keys
 * back, and must not leave a listener behind.
 */
@:access(states.InputTestState)
@:access(backend.TouchlessUI)
class InputTestStateSpec
{
  static inline var K:Int = InputTestLogic.KEYBOARD;
  static inline var G:Int = InputTestLogic.GAMEPAD;
  static inline var T:Int = InputTestLogic.TOUCH;

  /** One update of a 60 fps game, in seconds. */
  static inline var FRAME:Float = 1 / 60;

  /** The scripted clock the page reads, in milliseconds. */
  static var now:Float = 0;

  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<V>(actual:V, expected:V, label:String):Void
  {
    if (actual != expected) throw '$label: expected "$expected", got "$actual"';
  }

  static function has(text:String, part:String, label:String):Void
  {
    if (text.indexOf(part) == -1) throw '$label: "$part" is not in "$text"';
  }

  /* ------------------------------------------------------------------ */
  /* The world                                                          */
  /* ------------------------------------------------------------------ */
  /** A fresh game with the player's normal settings; the page is not open yet. */
  static function world():Void
  {
    FlxG.reset();
    FlxG.sound.muteKeys = TitleState.muteKeys;
    FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
    FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
    ClientPrefs.keyBinds = ClientPrefs.defaultKeyBinds();
    ClientPrefs.androidTVNavigation = false;
    MobileControls.enabled = false;
    MusicBeatState.windowNameSuffix = '';
    ViewportVisuals.covers = 0;
    backend.TouchlessUI.backThisFrame = false;
    now = 5000;
  }

  /** Opens the page in the current world. */
  static function start(fromOptions:Bool = false):InputTestState
  {
    final page = new InputTestState(fromOptions);
    page.clock = () -> now;
    page.create();
    return page;
  }

  static function open(fromOptions:Bool = false):InputTestState
  {
    world();
    return start(fromOptions);
  }

  /** Runs game updates; the clock moves one frame before each. */
  static function frames(page:InputTestState, count:Int = 1):Void
  {
    for (_ in 0...count)
    {
      now += FRAME * 1000;
      page.update(FRAME);
    }
  }

  static function keyDown(key:Int):Void
    FlxG.stage.key(KeyboardEvent.KEY_DOWN, key);

  static function keyUp(key:Int):Void
    FlxG.stage.key(KeyboardEvent.KEY_UP, key);

  static function pad():FlxGamepad
  {
    final gamepad = new FlxGamepad();
    FlxG.gamepads.pads = [gamepad];
    return gamepad;
  }

  static function finger(id:Int, x:Float, y:Float):FlxTouch
  {
    final touch = new FlxTouch(id, Std.int(x), Std.int(y));
    FlxG.touches.list.push(touch);
    return touch;
  }

  /* ------------------------------------------------------------------ */
  /* Reading the page                                                   */
  /* ------------------------------------------------------------------ */
  /** The value of an aligned `label   value` row in one of the panels. */
  static function row(text:String, label:String):String
  {
    for (line in text.split('\n'))
      if (line.indexOf(label) == 0) return StringTools.trim(line.substr(label.length));
    throw 'no "$label" row in "$text"';
  }

  static function counter(page:InputTestState, device:Int, label:String):String
    return row(page.deviceTexts[device].text, label);

  /** Second line of a device panel: how the device is read. */
  static function status(page:InputTestState, device:Int):String
    return page.deviceTexts[device].text.split('\n')[1];

  /** The end of a device panel, below the counters: the held names, or the idle prompt. */
  static function names(page:InputTestState, device:Int):String
    return page.deviceTexts[device].text.split('\n').slice(7).join('\n');

  static function timing(page:InputTestState, label:String):String
    return row(page.timingText.text, label);

  static function left(page:InputTestState):Bool
    return FlxG.switched.length > 0;

  static function exitX(page:InputTestState):Float
    return page.exitPanel.x + page.exitPanel.width / 2;

  static function exitY(page:InputTestState):Float
    return page.exitPanel.y + page.exitPanel.height / 2;

  static function textSets(page:InputTestState):Int
  {
    var total:Int = 0;
    for (member in page.members)
      if (Std.isOfType(member, FlxText)) total += cast(member, FlxText).textSets;
    return total;
  }

  static function visibleMarkers(page:InputTestState):Int
  {
    var count:Int = 0;
    for (slot in 0...page.markerRows.length)
    {
      final shown:Bool = page.markerRows[slot].visible;
      final whole:Bool = page.markerColumns[slot].visible == shown && page.markerLabels[slot].visible == shown;
      check(whole, 'a crosshair is drawn whole or not at all');
      if (shown) count++;
    }
    return count;
  }

  /* ------------------------------------------------------------------ */
  /* The cases                                                          */
  /* ------------------------------------------------------------------ */
  static function main():Void
  {
    testOpeningThePage();
    testAChordOnTheKeyboard();
    testKeysTheGameNormallyReactsTo();
    testWhatTheTimingPanelSays();
    testIdleFramesRebuildNothing();
    testGamepads();
    testFingers();
    testATapNeverLeaves();
    testHoldingBackLeaves();
    testBackBindsAreHonoured();
    testAGamepadCanLeave();
    testTheExitButton();
    testTheMouseOnExit();
    testAndroidSystemBack();
    testFocusLoss();
    testResizing();
    testClosingThePage();
    testNothingIsWritten();
    Sys.println('InputTestStateSpec passed');
  }

  static function testOpeningThePage():Void
  {
    final page = open();
    check(page.created, 'the base state was created');
    check(page.persistentUpdate, 'the page keeps updating');
    equal(MusicBeatState.windowNameSuffix, ' - Input Tester', 'the window title names the page');

    final untouched:String = 'held now        0\nmost at once    0\npresses         0';
    equal(page.deviceTexts[K].text, 'KEYBOARD\ntimed as events arrive\n\n' + untouched + '\n\npress some keys', 'keyboard panel');
    equal(page.deviceTexts[G].text, 'GAMEPAD\nnone connected\n\n' + untouched + '\n\nplug in a gamepad', 'gamepad panel');
    equal(page.deviceTexts[T].text, 'TOUCH\nread once per frame\n\n' + untouched + '\n\nput fingers on the screen', 'touch panel');
    equal(page.introText.text, [
      'Hold several keys, buttons or fingers together: "held now" is how many of them the game sees.',
      'A count that stops short of what you are holding means the device does not report more.'
    ].join('\n'), 'the intro says what the counters mean');
    has(page.timingText.text, 'PRESS TIMING\nlast press     -\nlast release   -\nlast chord     -\n', 'the timing panel starts empty');
    final note:String = [
      'Keys are timed the moment their event arrives.',
      'Gamepad buttons and touches are read once per',
      'frame, so theirs are whole frames apart.'
    ].join('\n');
    check(StringTools.endsWith(page.timingText.text, ' inside one frame\n\n' + note), 'and ends by saying why devices are timed differently');
    equal(page.historyText.text, 'LATEST FIRST\nnothing pressed yet', 'the history starts empty');
    equal(page.hintText.text, 'To leave, hold Escape or BckSpc alone for a second   |   gamepad: hold B or Back   |   mouse: hold EXIT',
      'the hint names the keys that leave');
    equal(page.exitText.text, 'EXIT\n(hold)', 'the exit button says it has to be held');

    check(FlxG.mouse.visible, 'the EXIT button answers to a mouse, so the pointer is shown');
    check(!page.exitBar.visible && !page.exitBarBack.visible, 'no leave progress yet');
    equal(visibleMarkers(page), 0, 'no crosshairs without fingers');
    equal(page.bg.loadedGraphic, 'image:menuDesat', 'the menu backdrop');
    equal(ViewportVisuals.covers, 1, 'fitted to the viewport');

    frames(page, 240);
    check(!left(page), 'four idle seconds do not close the page');
    equal(FlxG.sound.played.length, 0, 'and play nothing');

    // A phone gets the instruction that fits it.
    world();
    MobileControls.enabled = true;
    equal(start().hintText.text, 'Hold EXIT with one finger for a second to leave, or press Back.', 'the touch hint');

    // A TV has no pointer to show.
    world();
    ClientPrefs.androidTVNavigation = true;
    start();
    check(!FlxG.mouse.visible, 'touchless TV mode keeps the pointer hidden');
  }

  static function testAChordOnTheKeyboard():Void
  {
    final page = open();
    keyDown(FlxKey.A);
    keyDown(FlxKey.S);
    keyDown(FlxKey.D);
    frames(page);
    equal(counter(page, K, 'held now'), '3', 'three keys held, three shown');
    equal(names(page, K), 'A  S  D', 'by name, in press order');
    equal(counter(page, G, 'held now') + counter(page, T, 'held now'), '00', 'the other devices stay at zero');

    // The keyboard only reports the first two of the next chord.
    keyUp(FlxKey.A);
    keyUp(FlxKey.S);
    keyUp(FlxKey.D);
    frames(page);
    equal(names(page, K), 'press some keys', 'the prompt is back once the keys are up');
    keyDown(FlxKey.J);
    keyDown(FlxKey.K);
    frames(page, 30);
    equal(counter(page, K, 'held now'), '2', 'a key the keyboard never sent is not counted');
    equal(names(page, K), 'J  K', 'and not named');
    equal(counter(page, K, 'most at once'), '3', 'the best chord so far stays on screen');
    equal(counter(page, K, 'presses'), '5', 'every press was counted');

    // Auto-repeat: the OS sends the held key again and again.
    for (_ in 0...40)
      keyDown(FlxKey.J);
    frames(page);
    equal(counter(page, K, 'presses'), '5', 'repeats of a held key are not presses');
    equal(counter(page, K, 'held now'), '2', 'and do not hold it twice');

    // A full-rollover keyboard: every letter at once, then the digits as well.
    keyUp(FlxKey.J);
    keyUp(FlxKey.K);
    for (letter in 0...26)
      keyDown(FlxKey.A + letter);
    frames(page);
    equal(counter(page, K, 'held now'), '26', 'all twenty-six letters are counted');
    equal(names(page, K), 'A  B  C  D  E  F  G  H  I  J\nK  L  M  N  O  P  Q  R  S  T\nU  V  W  X  Y  Z', 'and named, on lines as wide as the panel');
    for (digit in 0...10)
      keyDown(FlxKey.ZERO + digit);
    frames(page);
    equal(counter(page, K, 'held now'), '36', 'thirty-six keys are counted');
    equal(names(page, K), 'A  B  C  D  E  F  G  H  I  J\nK  L  M  N  O  P  Q  R  S  T\nU  V  W  X  Y  Z  0  +9 more',
      'the list is summed up instead of growing out of its panel');
    checkLayout(page, 'thirty-six keys');
  }

  static function testKeysTheGameNormallyReactsTo():Void
  {
    world();
    check(FlxG.sound.muteKeys.length == 1 && FlxG.sound.volumeUpKeys.length == 2, 'the volume shortcuts are active before the page opens');
    final page = start();
    equal(FlxG.sound.muteKeys.length + FlxG.sound.volumeDownKeys.length + FlxG.sound.volumeUpKeys.length, 0,
      'while the page is open no key mutes or changes the volume');

    keyDown(FlxKey.ZERO);
    keyDown(FlxKey.MINUS);
    keyDown(FlxKey.PLUS);
    frames(page);
    equal(names(page, K), '0  Minus  Plus', 'the volume keys are shown like any other key');

    // Keys Flixel has no name for still show up; they are just not bindable.
    keyUp(FlxKey.ZERO);
    keyUp(FlxKey.MINUS);
    keyUp(FlxKey.PLUS);
    keyDown(255);
    keyDown(0x4000010C);
    frames(page);
    equal(names(page, K), 'Key 255  Key 1073742092', 'an unnamed key is shown by its code');
    check(!left(page), 'and nothing here closed the page');
  }

  static function testWhatTheTimingPanelSays():Void
  {
    final page = open();

    // Keys are timed when their event arrives, between two updates.
    keyDown(FlxKey.A);
    now += 4;
    keyDown(FlxKey.S);
    now += 8.5;
    keyDown(FlxKey.D);
    frames(page);
    equal(timing(page, 'last press'), 'D  +8.5 ms', 'the gap is measured between the events, not between frames');
    equal(timing(page, 'last chord'), '3 at once, built in 12.5 ms', 'and so is the time the chord took');
    equal(timing(page, 'most per frame'), '3 presses in one frame (16.7 ms)', 'all three landed before one update');
    equal(timing(page, 'last release'), '-', 'nothing released yet');

    now += 20;
    keyUp(FlxKey.A);
    frames(page);
    has(timing(page, 'last release'), 'A  held ', 'a release shows which key and for how long');
    equal(timing(page, 'short taps'), '0 down and up inside one frame', 'these were all held across an update');

    // Down and up again before the game updates once.
    keyDown(FlxKey.F);
    now += 3;
    keyUp(FlxKey.F);
    frames(page);
    equal(timing(page, 'last release'), 'F  held 3.0 ms', 'a 3 ms tap is measured');
    equal(timing(page, 'short taps'), '1 down and up inside one frame', 'and flagged: a once-per-frame poll would never see it held');
    equal(page.historyText.text.split('\n')[1], 'up    F            held 3.0 ms', 'the history lists the newest event first');
    // D went down two updates and 20 ms before F: 2 * 16.67 + 20.
    equal(page.historyText.text.split('\n')[2], 'down  F            +53.3 ms    3 held', 'with the gap and what was held at that moment');

    // A pad is read once per update, so its presses are whole frames apart.
    final gamepad = pad();
    gamepad.down = [A];
    frames(page);
    gamepad.down = [A, X];
    frames(page);
    equal(timing(page, 'last press'), 'X  +16.7 ms', 'one frame between two pad buttons');
    gamepad.down = [A, X, Y, LEFT_SHOULDER];
    frames(page);
    equal(timing(page, 'last press'), 'LB  +0.0 ms', 'two buttons read in the same update arrive together');

    // The explanation follows the game's update rate.
    FlxG.updateFramerate = 240;
    gamepad.down = [];
    frames(page);
    has(page.timingText.text, 'in one frame (4.2 ms)', 'the frame length shown is the current one');
  }

  static function testIdleFramesRebuildNothing():Void
  {
    final page = open();
    keyDown(FlxKey.A);
    final gamepad = pad();
    gamepad.down = [X];
    finger(1, 300, 300);
    frames(page);
    final before:Int = textSets(page);

    frames(page, 120);
    equal(textSets(page), before, 'two seconds of holding three inputs still assign no text');

    keyUp(FlxKey.A);
    equal(textSets(page), before, 'a key event alone does not draw');
    frames(page);
    check(textSets(page) > before, 'the next update shows the change');

    // Plugging a pad in changes a status line without any press.
    final again:Int = textSets(page);
    FlxG.gamepads.pads.push(new FlxGamepad());
    frames(page);
    check(textSets(page) > again, 'a newly connected pad is shown at once');
  }

  static function testGamepads():Void
  {
    final page = open();
    final first = pad();
    frames(page);
    equal(status(page, G), '1 pad, read once per frame', 'a connected pad is announced');
    equal(names(page, G), 'press some buttons', 'with a prompt that fits');

    first.down = [A, X, LEFT_SHOULDER];
    frames(page);
    equal(counter(page, G, 'held now'), '3', 'three buttons');
    equal(names(page, G), 'A  X  LB', 'named the way this model of pad labels them');

    first.down = [X];
    frames(page);
    equal(counter(page, G, 'held now'), '1', 'two buttons were let go');
    equal(counter(page, G, 'most at once'), '3', 'the peak stays');

    // A stick pushed left is one input, and it has no label on this pad.
    first.down = [LEFT_STICK_DIGITAL_LEFT, DPAD_UP];
    frames(page);
    equal(names(page, G), 'DPAD_UP\nLEFT_STICK_DIGITAL_LEFT', 'an unlabelled input falls back to its id, on a line of its own if it is long');

    // A second pad in a later slot: the same button is a different input.
    final second = new FlxGamepad();
    FlxG.gamepads.pads = [first, null, second];
    first.down = [A];
    second.down = [A, Y];
    frames(page);
    equal(status(page, G), '2 pads, read once per frame', 'both pads are counted, the empty slot is skipped');
    equal(counter(page, G, 'held now'), '3', 'A on two pads is two buttons');
    equal(names(page, G), 'A  P3 A  P3 Y', 'the second pad is told apart by its slot');

    // Unplugging: the pad is no longer read and its buttons are gone.
    second.connected = false;
    final reads:Int = second.reads;
    frames(page, 5);
    equal(second.reads, reads, 'a disconnected pad is not polled');
    equal(status(page, G), '1 pad, read once per frame', 'and not counted');
    equal(names(page, G), 'A', 'only the first pad still holds something');

    FlxG.gamepads.pads = [];
    frames(page);
    equal(status(page, G), 'none connected', 'no pads left');
    equal(names(page, G), 'plug in a gamepad', 'back to the first prompt');
    equal(counter(page, G, 'held now'), '0', 'nothing is held on a pad that is gone');
    check(!left(page), 'none of this closed the page');
  }

  static function testFingers():Void
  {
    final page = open();
    final one = finger(701, 100, 200);
    final two = finger(702, 400, 300);
    final three = finger(703, 640, 500);
    frames(page);
    equal(counter(page, T, 'held now'), '3', 'three fingers');
    equal(names(page, T), 'Finger 1  Finger 2  Finger 3', 'numbered in the order they landed');
    equal(visibleMarkers(page), 3, 'each gets a crosshair');
    equal(page.markerRows[0].y, 199, 'the horizontal line runs through the finger');
    equal(page.markerColumns[0].x, 99, 'and so does the vertical one');
    equal(page.markerRows[0].width, 1280, 'across the whole screen');
    equal(page.markerColumns[0].height, 720, 'top to bottom');
    equal(page.markerLabels[2].text, '3', 'with its number beside it');

    // Dragging is not pressing.
    two.screenX = 900;
    two.screenY = 650;
    frames(page);
    equal(page.markerColumns[1].x, 899, 'the crosshair follows the finger');
    equal(page.markerRows[1].y, 649, 'in both directions');
    equal(counter(page, T, 'presses'), '3', 'and a moving finger is not a new press');

    // A number never hangs off the right edge.
    two.screenX = 1279;
    frames(page);
    check(page.markerLabels[1].x + 44 <= FlxG.width, 'the number stays on screen at the right edge');
    two.screenY = 0;
    frames(page);
    check(page.markerLabels[1].y >= 0, 'and at the top');

    // Flixel lists a lifted finger for one more frame, no longer pressed.
    one.pressed = false;
    frames(page);
    equal(counter(page, T, 'held now'), '2', 'a lifted finger is released even while it is still listed');
    check(!page.markerRows[0].visible, 'its crosshair goes away');
    equal(names(page, T), 'Finger 2  Finger 3', 'the fingers still down keep their numbers');
    check(page.markerRows[1].visible && page.markerRows[2].visible, 'and their crosshairs');

    FlxG.touches.list.remove(one);
    FlxG.touches.list.push(null);
    final four = finger(704, 50, 60);
    frames(page);
    equal(names(page, T), 'Finger 2  Finger 3  Finger 1', 'a new finger takes the free number');
    equal(page.markerColumns[0].x, 49, 'and the free crosshair');
    equal(counter(page, T, 'most at once'), '3', 'the panel never claimed more than three');

    // More fingers than crosshairs: still counted.
    FlxG.touches.list = [];
    frames(page);
    for (index in 0...12)
      finger(800 + index, 100 + index * 90, 400);
    frames(page);
    equal(counter(page, T, 'held now'), '12', 'a twelve-finger panel reads twelve');
    equal(visibleMarkers(page), 10, 'ten of them are drawn');
    equal(names(page, T), 'Finger 1  Finger 2  Finger 3\nFinger 4  Finger 5  Finger 6\nFinger 7  Finger 8  +4 more', 'and the list is summed up');
    checkLayout(page, 'twelve fingers');

    FlxG.touches.list = [];
    frames(page);
    equal(visibleMarkers(page), 0, 'every crosshair is cleared when the hands are off');
    equal(counter(page, T, 'most at once'), '12', 'the count stays to be read');
    check(four != null && three != null && !left(page), 'none of this closed the page');
  }

  static function testATapNeverLeaves():Void
  {
    final page = open();

    // Escape, tapped the way a menu would be closed.
    keyDown(FlxKey.ESCAPE);
    frames(page, 20);
    check(page.exitBar.visible && page.exitBarBack.visible, 'holding Escape shows that something is filling up');
    check(page.exitBar.width > 100 && page.exitBar.width < 140, 'a third of the way after a third of a second: ' + page.exitBar.width);
    equal(page.exitBarBack.width, 360, 'against a full-width track');
    keyUp(FlxKey.ESCAPE);
    frames(page);
    check(!page.exitBar.visible && !page.exitBarBack.visible, 'letting go cancels it');
    check(!left(page), 'and the page is still open');
    equal(counter(page, K, 'presses'), '1', 'Escape was counted as the key it is');
    has(page.historyText.text, 'down  Escape', 'and logged');

    // Mashing every way out for ten seconds.
    final gamepad = pad();
    for (round in 0...60)
    {
      keyDown(FlxKey.ESCAPE);
      keyDown(FlxKey.BACKSPACE);
      gamepad.down = [B, BACK];
      FlxG.mouse.pressed = true;
      FlxG.mouse.screenX = Std.int(exitX(page));
      FlxG.mouse.screenY = Std.int(exitY(page));
      frames(page, 5);
      keyUp(FlxKey.ESCAPE);
      keyUp(FlxKey.BACKSPACE);
      gamepad.down = [];
      FlxG.mouse.pressed = false;
      frames(page, 5);
    }
    check(!left(page), 'no amount of tapping closes the page');
    equal(FlxG.sound.played.length, 0, 'or makes the cancel sound');

    // A chord that contains a way out is still a chord.
    keyDown(FlxKey.ESCAPE);
    keyDown(FlxKey.A);
    gamepad.down = [A, B, X];
    frames(page, 300);
    check(!left(page), 'Escape+A and A+B+X held for five seconds stay on the page');
    check(!page.exitBar.visible, 'without even starting the bar');
  }

  static function testHoldingBackLeaves():Void
  {
    var page = open();
    keyDown(FlxKey.ESCAPE);
    frames(page, 58);
    check(!left(page), 'not before the second is up');
    frames(page, 4);
    equal(FlxG.switched.join(','), 'states.MainMenuState', 'holding Escape alone leaves to the Main Menu');
    equal(FlxG.sound.played.join(','), 'sound:cancelMenu', 'with the menu cancel sound');
    frames(page, 120);
    equal(FlxG.switched.length, 1, 'the switch is requested once, however long the key stays down');
    equal(FlxG.sound.played.length, 1, 'and the sound plays once');

    // Opened from Options: Back returns there, the way every options page does.
    page = open(true);
    keyDown(FlxKey.BACKSPACE);
    frames(page, 62);
    equal(FlxG.switched.join(','), 'options.OptionsState', 'the Options entry leads back to Options');

    // Something else was down first: the hold only counts once it is alone.
    page = open();
    keyDown(FlxKey.A);
    keyDown(FlxKey.ESCAPE);
    frames(page, 200);
    check(!left(page), 'Escape is not alone yet');
    keyUp(FlxKey.A);
    frames(page, 58);
    check(!left(page), 'the second starts when the other key is released');
    frames(page, 4);
    check(left(page), 'and then it leaves');

    // A pad with a button stuck down does not trap a keyboard player.
    page = open();
    pad().down = [RIGHT_STICK_DIGITAL_LEFT];
    keyDown(FlxKey.ESCAPE);
    frames(page, 62);
    check(left(page), 'the keyboard leaves on its own, whatever a pad is doing');
  }

  static function testBackBindsAreHonoured():Void
  {
    // The player moved Back to Q; a hardware bind and an empty slot sit beside it.
    world();
    ClientPrefs.keyBinds.set('back', [FlxKey.Q, FlxKey.NONE, HardwareKeys.toBind(HardwareKeys.KEYCODE_VOLUME_DOWN)]);
    var page = start();
    has(page.hintText.text, 'hold Escape or Q alone', 'the hint names the bound key, and only real keys');
    keyDown(FlxKey.Q);
    frames(page, 62);
    check(left(page), 'the bound key leaves');

    world();
    ClientPrefs.keyBinds.set('back', [FlxKey.Q]);
    page = start();
    keyDown(FlxKey.BACKSPACE);
    frames(page, 200);
    check(!left(page), 'a key that is no longer bound to Back is just a key');
    keyUp(FlxKey.BACKSPACE);
    keyDown(FlxKey.ESCAPE);
    frames(page, 62);
    check(left(page), 'Escape always works, so a broken bind cannot trap anyone');

    // No Back bind at all.
    world();
    ClientPrefs.keyBinds.remove('back');
    page = start();
    has(page.hintText.text, 'hold Escape alone', 'only Escape is offered');
    keyDown(FlxKey.ESCAPE);
    frames(page, 62);
    check(left(page), 'and it leaves');
  }

  static function testAGamepadCanLeave():Void
  {
    var page = open();
    var gamepad = pad();
    gamepad.down = [B];
    frames(page, 58);
    check(!left(page), 'B has to be held too');
    frames(page, 4);
    check(left(page), 'B held alone leaves');

    page = open();
    gamepad = pad();
    gamepad.down = [BACK];
    frames(page, 62);
    check(left(page), 'so does the Back button');

    page = open();
    gamepad = pad();
    gamepad.down = [A];
    frames(page, 300);
    check(!left(page), 'any other button is only a button');

    // A stick that drifts is "held" for good: that pad cannot leave, others can.
    page = open();
    gamepad = pad();
    gamepad.down = [LEFT_STICK_DIGITAL_UP, B];
    frames(page, 300);
    check(!left(page), 'B next to a drifting stick is not B alone');
    FlxG.mouse.pressed = true;
    FlxG.mouse.screenX = Std.int(exitX(page));
    FlxG.mouse.screenY = Std.int(exitY(page));
    frames(page, 62);
    check(left(page), 'the EXIT button is the way out');
  }

  static function testTheExitButton():Void
  {
    var page = open();
    finger(1, exitX(page), exitY(page));
    frames(page, 58);
    check(!left(page), 'a finger on EXIT has to stay there');
    check(page.exitBar.visible, 'the bar shows it is working');
    equal(counter(page, T, 'held now'), '1', 'and it is still a finger like any other');
    frames(page, 4);
    check(left(page), 'one finger held on EXIT leaves');

    // Fingers need more room than the art: the same margin as every touch target.
    page = open();
    check(page.exitZone.width >= 88 && page.exitZone.height >= 88, 'the hit area is at least 88 px each way');
    finger(1, page.exitPanel.x - 10, page.exitPanel.y + page.exitPanel.height + 10);
    frames(page, 62);
    check(left(page), 'a finger just outside the drawn button still counts');

    page = open();
    finger(1, page.exitPanel.x - 40, exitY(page));
    frames(page, 300);
    check(!left(page), 'a finger well outside does not');

    // Somewhere else entirely.
    page = open();
    finger(1, 640, 400);
    frames(page, 300);
    check(!left(page), 'a finger resting on the screen is the test, not a goodbye');

    // A multi-touch test with one finger that happens to be on EXIT.
    page = open();
    finger(1, exitX(page), exitY(page));
    final other = finger(2, 300, 500);
    finger(3, 700, 500);
    frames(page, 300);
    check(!left(page), 'three fingers, one of them on EXIT, stay on the page');
    equal(counter(page, T, 'held now'), '3', 'and all three are counted');
    FlxG.touches.list.pop();
    FlxG.touches.list.remove(other);
    frames(page, 58);
    check(!left(page), 'lifting the others starts the hold from zero');
    frames(page, 4);
    check(left(page), 'and then the finger on EXIT leaves');

    // Landing elsewhere and sliding onto EXIT was not aimed at EXIT.
    page = open();
    final slider = finger(1, 300, 400);
    frames(page, 3);
    slider.screenX = Std.int(exitX(page));
    slider.screenY = Std.int(exitY(page));
    frames(page, 300);
    check(!left(page), 'a finger that slid onto EXIT does not leave');
  }

  static function testTheMouseOnExit():Void
  {
    var page = open();
    FlxG.mouse.pressed = true;
    FlxG.mouse.screenX = Std.int(exitX(page));
    FlxG.mouse.screenY = Std.int(exitY(page));
    frames(page, 58);
    check(!left(page), 'the mouse has to hold EXIT too');
    frames(page, 4);
    check(left(page), 'holding EXIT with the mouse leaves');

    page = open();
    FlxG.mouse.pressed = true;
    FlxG.mouse.screenX = 640;
    FlxG.mouse.screenY = 400;
    frames(page, 300);
    check(!left(page), 'holding the mouse anywhere else does nothing');

    // Hovering is not holding.
    page = open();
    FlxG.mouse.screenX = Std.int(exitX(page));
    FlxG.mouse.screenY = Std.int(exitY(page));
    frames(page, 300);
    check(!left(page), 'a pointer resting over EXIT does nothing');

    // The way out when a key is stuck down (or was never released).
    page = open();
    keyDown(FlxKey.A);
    FlxG.mouse.pressed = true;
    FlxG.mouse.screenX = Std.int(exitX(page));
    FlxG.mouse.screenY = Std.int(exitY(page));
    frames(page, 62);
    check(left(page), 'the mouse leaves even while a key is held');

    // Phones report the first finger as the mouse as well. The touch rules
    // (alone, and landed on EXIT) must not be bypassed by that echo.
    page = open();
    finger(1, exitX(page), exitY(page));
    finger(2, 300, 500);
    FlxG.mouse.pressed = true;
    FlxG.mouse.screenX = Std.int(exitX(page));
    FlxG.mouse.screenY = Std.int(exitY(page));
    frames(page, 300);
    check(!left(page), 'two fingers stay on the page even if the first one also moves the mouse');
  }

  static function testAndroidSystemBack():Void
  {
    final page = open();
    keyDown(FlxKey.A);
    finger(1, 300, 300);
    frames(page, 10);
    backend.TouchlessUI.backThisFrame = true;
    frames(page);
    equal(FlxG.switched.join(','), 'states.MainMenuState', 'the system Back button or gesture leaves at once, whatever is held');
    equal(FlxG.sound.played.length, 1, 'with one cancel sound');
    frames(page, 5);
    equal(FlxG.switched.length, 1, 'a Back that is still reported does not switch twice');
  }

  static function testFocusLoss():Void
  {
    final page = open();
    keyDown(FlxKey.A);
    keyDown(FlxKey.S);
    frames(page);
    equal(counter(page, K, 'held now'), '2', 'two keys down');

    // Alt-tab: the key-up events go to another window and never arrive here.
    page.onFocusLost();
    frames(page);
    equal(counter(page, K, 'held now'), '0', 'nothing stays "held" after the window lost focus');
    equal(counter(page, K, 'most at once'), '2', 'what was measured before stays');
    equal(timing(page, 'last release'), '-', 'and no release was invented');

    // Coming back: the same keys work again.
    keyDown(FlxKey.A);
    frames(page);
    equal(counter(page, K, 'held now'), '1', 'a key pressed after returning is counted');
    keyUp(FlxKey.S);
    frames(page);
    equal(counter(page, K, 'held now'), '1', 'and the late release of a forgotten key changes nothing');
  }

  static function testResizing():Void
  {
    final page = open();
    final oldX:Float = exitX(page);
    final oldY:Float = exitY(page);
    checkLayout(page, '1280x720');

    // A widescreen viewport: the content stays centred, so EXIT moves.
    FlxG.width = 1920;
    page.onResize(1920, 720);
    equal(ViewportVisuals.covers, 2, 'the backdrop is fitted again');
    checkLayout(page, '1920x720');
    check(exitX(page) > oldX + 100, 'the EXIT button moved with the layout');

    finger(1, oldX, oldY);
    frames(page, 300);
    check(!left(page), 'the place where EXIT used to be is no longer EXIT');
    FlxG.touches.list = [];
    frames(page);
    finger(2, exitX(page), exitY(page));
    frames(page, 62);
    check(left(page), 'the hit area moved with the button');
    equal(page.markerRows[0].width, 1920, 'and the crosshairs span the new width');

    // A resize that arrives before the page was created must not crash.
    world();
    new InputTestState().onResize(1280, 720);
  }

  /** Everything is on screen, in reading order, and nothing overlaps its neighbour. */
  static function checkLayout(page:InputTestState, label:String):Void
  {
    var previous:FlxSprite = null;
    for (panel in page.devicePanels)
    {
      check(panel.x >= 0 && panel.x + panel.width <= FlxG.width, '$label: a device panel is on screen');
      check(panel.width >= 150, '$label: a device panel has room for its counters');
      if (previous != null) check(panel.x >= previous.x + previous.width, '$label: device panels do not overlap');
      previous = panel;
    }
    for (device in 0...InputTestLogic.DEVICES)
    {
      final box = page.devicePanels[device];
      final text = page.deviceTexts[device];
      check(text.x >= box.x && text.x + text.fieldWidth <= box.x + box.width, '$label: device text stays inside its panel');
      check(text.y >= box.y && text.y + text.height <= box.y + box.height, '$label: device text fits its panel');
    }

    final exit = page.exitPanel;
    check(exit.x >= 0 && exit.x + exit.width <= FlxG.width && exit.y >= 0, '$label: EXIT is on screen');
    check(exit.y + exit.height <= page.devicePanels[0].y, '$label: EXIT sits above the device panels');
    check(page.introText.x + page.introText.fieldWidth <= exit.x, '$label: the intro text stops before EXIT');
    equal(page.exitZone.x + page.exitZone.width / 2, exit.x + exit.width / 2, '$label: the hit area is centred on EXIT');
    check(page.exitZone.y + page.exitZone.height <= page.devicePanels[0].y, '$label: the hit area does not reach into the panels');

    final timing = page.timingPanel;
    check(timing.y >= page.devicePanels[0].y + page.devicePanels[0].height, '$label: the timing panel is below the device panels');
    check(timing.x >= 0 && timing.x + timing.width <= FlxG.width, '$label: the timing panel is on screen');
    check(page.timingText.x + page.timingText.fieldWidth <= page.historyText.x, '$label: timing and history are side by side');
    check(page.historyText.x + page.historyText.fieldWidth <= timing.x + timing.width, '$label: the history stays inside the panel');

    final hint = page.hintText;
    check(hint.y + hint.height <= FlxG.height, '$label: the hint is on screen');
    check(timing.y + timing.height <= hint.y, '$label: the timing panel ends above the hint');
    check(page.exitBarBack.y + page.exitBarBack.height <= hint.y, '$label: the leave bar sits above the hint');
    check(page.exitBarBack.y >= timing.y + timing.height, '$label: and below the timing panel');
    equal(page.exitBar.x, page.exitBarBack.x, '$label: the bar fills its track from the left');
  }

  static function testClosingThePage():Void
  {
    final page = open();
    equal(FlxG.stage.listenerCount(), 2, 'the page listens for key down and key up');
    keyDown(FlxKey.A);
    frames(page);

    page.destroy();
    check(page.destroyed, 'the base state was destroyed');
    equal(FlxG.stage.listenerCount(), 0, 'no listener is left on the stage');
    check(FlxG.sound.muteKeys == TitleState.muteKeys, 'the mute key is handed back');
    check(FlxG.sound.volumeDownKeys == TitleState.volumeDownKeys, 'and volume down');
    check(FlxG.sound.volumeUpKeys == TitleState.volumeUpKeys, 'and volume up');

    // The next state's key presses are none of this page's business.
    final revision:Int = page.logic.revision;
    keyDown(FlxKey.S);
    keyUp(FlxKey.A);
    equal(page.logic.revision, revision, 'a destroyed page hears nothing');

    // Opening it twice in a row (deep link while it is already open) stacks nothing.
    world();
    final first = start();
    first.destroy();
    start();
    equal(FlxG.stage.listenerCount(), 2, 'a reopened page has one pair of listeners, not two');

    // The pointer is borrowed for the EXIT button and handed back as it was.
    world();
    final hidden = start();
    check(FlxG.mouse.visible, 'shown while the page is open');
    hidden.destroy();
    check(!FlxG.mouse.visible, 'a menu that had no pointer gets none back');

    world();
    FlxG.mouse.visible = true;
    start().destroy();
    check(FlxG.mouse.visible, 'a screen that showed the pointer still has it');

    world();
    FlxG.mouse.visible = true;
    start(true).destroy();
    check(!FlxG.mouse.visible, 'the Options list never shows one, so the page hides it on the way back there');
  }

  static function testNothingIsWritten():Void
  {
    world();
    final binds = ClientPrefs.keyBinds;
    final back = binds.get('back');
    final mute = TitleState.muteKeys;
    final page = start();
    for (key in [FlxKey.A, FlxKey.ZERO, FlxKey.BACKSPACE, FlxKey.Q])
    {
      keyDown(key);
      frames(page, 3);
      keyUp(key);
    }
    keyDown(FlxKey.ESCAPE);
    frames(page, 62);
    check(left(page), 'the session ended');
    page.destroy();

    check(ClientPrefs.keyBinds == binds && binds.get('back') == back, 'the bind table is the same object');
    equal(back.join(','), [FlxKey.BACKSPACE, FlxKey.ESCAPE].join(','), 'with the same Back keys');
    check(TitleState.muteKeys == mute && mute.length == 1, 'the stored volume shortcuts were not touched');
    check(ClientPrefs.globalAntialiasing && !ClientPrefs.androidTVNavigation && ClientPrefs.uiScalePercent == 100, 'and neither was any preference');
  }
}
