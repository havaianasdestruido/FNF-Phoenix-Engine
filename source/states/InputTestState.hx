package states;

import backend.ClientPrefs;
import backend.HoldToConfirmLogic;
import backend.HoldToConfirmLogic.TouchRect;
import backend.InputFormatter;
import backend.InputTestLogic;
import backend.InputTestLogic.InputNamer;
import backend.MusicBeatState;
import backend.Paths;
import backend.ScreenLayout;
import backend.TouchlessUI;
import backend.ViewportVisuals;
import flixel.input.gamepad.FlxGamepad;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import openfl.events.KeyboardEvent;

/**
 * The input tester: the page behind `phoenix://input` and Options -> Gameplay -> Input Tester.
 *
 * A live view of what the game itself receives: every key that is down, every
 * gamepad button, every finger on the screen. Each device gets a "held now"
 * counter and the most it ever held at once, so a keyboard that drops the
 * third key of a chord or a phone that tracks two fingers is visible at a
 * glance. A timing panel shows how far apart presses arrived, how many landed
 * inside a single frame and how many taps went down and came back up inside
 * one. That is the player-facing half of the poll-rate and key-rollover audit
 * (TODO.md §15): gameplay judges key presses as their events arrive, while
 * menus, gamepads and touch controls are read once per frame.
 *
 * The counting lives in `backend.InputTestLogic`; this class only feeds it and
 * draws it. Keyboard input comes from the stage's key events, exactly where
 * `PlayState` listens, and is timed on arrival. Gamepads and touches are read
 * from `FlxG.gamepads` / `FlxG.touches` once per update, which is all the
 * engine ever sees of them.
 *
 * Every input is a test subject, so nothing here reacts to a tap: leaving is
 * a one second hold on a Back key, a pad's B or Back button, or the on-screen
 * EXIT button, with nothing else held on that device. Android's system Back
 * leaves immediately. The volume shortcuts are parked while the page is open
 * (they are keys too) and restored on the way out. The page binds, saves and
 * writes nothing.
 *
 * Out of its reach: the engine-wide desktop hotkeys, which are handled outside
 * any state and keep working here as they do during a song (F2 screenshot,
 * F3 and F6 frame profiler, F11 fullscreen).
 */
class InputTestState extends MusicBeatState
{
  /** Crosshairs drawn for touches; more fingers than this are still counted. */
  static inline final TOUCH_MARKERS:Int = 10;

  /** Gamepad slots checked every frame. */
  static inline final MAX_GAMEPADS:Int = 8;

  /** Room for every `FlxGamepadInputID` of one pad inside a single input code. */
  static inline final PAD_STRIDE:Int = 64;

  /** Lines the held names may take in a device panel; the rest is summed up as "+N more". */
  static inline final NAME_ROWS:Int = 3;

  /** Font size of the device panels. */
  static inline final DEVICE_FONT:Int = 20;

  /** Width of every glyph of the monospace UI font (vcr.ttf), as a fraction of the font size. */
  static inline final FONT_ADVANCE:Float = 0.586;

  static inline final MARGIN:Int = 40;
  static inline final CONTENT_WIDTH:Int = 1200;
  static inline final PANEL_GAP:Int = 12;
  static inline final PANEL_PADDING:Int = 14;
  static inline final DEVICE_TOP:Int = 84;
  static inline final DEVICE_HEIGHT:Int = 236;
  static inline final EXIT_WIDTH:Int = 150;
  static inline final EXIT_HEIGHT:Int = 56;
  static inline final EXIT_BAR_WIDTH:Int = 360;
  static inline final EXIT_BAR_HEIGHT:Int = 6;

  /**
   * What a pad can press. Stick directions are the digital ones `Controls`
   * binds; the raw axes and the motion/pointer ids are left out so one push of
   * a stick is one input, not two.
   */
  static final PAD_BUTTONS:Array<FlxGamepadInputID> = [
    A,
    B,
    X,
    Y,
    LEFT_SHOULDER,
    RIGHT_SHOULDER,
    LEFT_TRIGGER,
    RIGHT_TRIGGER,
    BACK,
    START,
    GUIDE,
    LEFT_STICK_CLICK,
    RIGHT_STICK_CLICK,
    DPAD_UP,
    DPAD_DOWN,
    DPAD_LEFT,
    DPAD_RIGHT,
    LEFT_STICK_DIGITAL_UP,
    LEFT_STICK_DIGITAL_DOWN,
    LEFT_STICK_DIGITAL_LEFT,
    LEFT_STICK_DIGITAL_RIGHT,
    RIGHT_STICK_DIGITAL_UP,
    RIGHT_STICK_DIGITAL_DOWN,
    RIGHT_STICK_DIGITAL_LEFT,
    RIGHT_STICK_DIGITAL_RIGHT,
    EXTRA_0,
    EXTRA_1,
    EXTRA_2,
    EXTRA_3
  ];

  /** The two sentences under the title; one entry per line. */
  static final INTRO:String = [
    'Hold several keys, buttons or fingers together: "held now" is how many of them the game sees.',
    'A count that stops short of what you are holding means the device does not report more.'
  ].join('\n');

  /** Under the timing readout: why keys and polled devices are not timed alike. One entry per line of the panel. */
  static final TIMING_NOTE:String = [
    'Keys are timed the moment their event arrives.',
    'Gamepad buttons and touches are read once per',
    'frame, so theirs are whole frames apart.'
  ].join('\n');

  static final MARKER_COLORS:Array<FlxColor> = [
    0xFFFF5C5C, 0xFF5CD0FF, 0xFF7CFC00, 0xFFFFD75C, 0xFFFF7CF0,
    0xFFFFFFFF, 0xFFFF9A3C, 0xFF9C8CFF, 0xFF5CFFC4, 0xFFC8C8C8
  ];

  /** Where Back leads: the Options list that opened the page, or the Main Menu. */
  final fromOptions:Bool;

  var logic:InputTestLogic = new InputTestLogic();

  /** Milliseconds; a field so the spec can drive the page with a scripted clock. */
  var clock:Void->Float = preciseTime;

  var bg:FlxSprite;
  var titleText:FlxText;
  var introText:FlxText;
  var devicePanels:Array<FlxSprite> = [];
  var deviceTexts:Array<FlxText> = [];
  var timingPanel:FlxSprite;
  var timingText:FlxText;
  var historyText:FlxText;
  var hintText:FlxText;
  var exitPanel:FlxSprite;
  var exitText:FlxText;
  var exitBarBack:FlxSprite;
  var exitBar:FlxSprite;
  var markerRows:Array<FlxSprite> = [];
  var markerColumns:Array<FlxSprite> = [];
  var markerLabels:Array<FlxText> = [];
  var markerUsed:Array<Bool> = [for (_ in 0...TOUCH_MARKERS) false];

  /** The enlarged EXIT hit area, in the same screen units pointers report. */
  var exitZone:TouchRect;

  /** Key codes that count for the leave gesture: Escape plus the Back binds. */
  var backKeys:Array<Int> = [];

  var namer:InputNamer;

  /** Characters that fit on one line of a device panel; see `layout`. */
  var nameColumns:Int = 0;

  var connectedPads:Int = 0;
  var shownPads:Int = -1;
  var shownRevision:Int = -1;
  var leaving:Bool = false;

  /** The pointer as the previous screen left it, to hand it back the same way. */
  var cursorWasVisible:Bool = false;

  /**
   * Only remembers where to return to; the page is built in `create()`.
   *
   * @param fromOptions `true` when the Options menu opened the page, so Back
   *                    returns there instead of to the Main Menu.
   */
  public function new(fromOptions:Bool = false)
  {
    super();
    this.fromOptions = fromOptions;
  }

  override public function onResize(width:Int, height:Int):Void
  {
    super.onResize(width, height);
    ViewportVisuals.cover(bg);
    if (hintText == null) return;
    layout();
    refresh();
  }

  override function create():Void
  {
    MusicBeatState.windowNameSuffix = " - Input Tester";
    persistentUpdate = true;

    super.create();

    namer = inputName;
    backKeys = exitKeys();

    bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
    bg.color = 0xFF3B4A6B;
    bg.antialiasing = ClientPrefs.globalAntialiasing;
    ViewportVisuals.cover(bg);
    add(bg);

    titleText = label(26, 'INPUT TESTER');
    introText = label(16, INTRO);

    for (device in 0...InputTestLogic.DEVICES)
    {
      devicePanels.push(panel());
      deviceTexts.push(label(DEVICE_FONT, ''));
    }

    timingPanel = panel();
    timingText = label(18, '');
    historyText = label(18, '');

    exitPanel = panel(0xE0202020);
    exitText = label(18, 'EXIT\n(hold)', CENTER);

    var hint:String = 'Hold EXIT with one finger for a second to leave, or press Back.';
    if (!mobile.MobileControls.enabled)
    {
      final keys:String = [for (key in backKeys) keyName(key)].join(' or ');
      hint = 'To leave, hold ' + keys + ' alone for a second   |   gamepad: hold B or Back   |   mouse: hold EXIT';
    }
    hintText = label(18, hint, CENTER);

    exitBarBack = panel(0xFF000000);
    exitBar = panel(0xFF7CFC00);
    exitBarBack.visible = exitBar.visible = false;

    // Last, so the crosshairs stay readable on top of the panels.
    for (slot in 0...TOUCH_MARKERS)
    {
      final color:FlxColor = MARKER_COLORS[slot % MARKER_COLORS.length];
      markerRows.push(marker(color));
      markerColumns.push(marker(color));
      final number:FlxText = label(22, Std.string(slot + 1));
      number.color = color;
      number.visible = false;
      markerLabels.push(number);
    }

    layout();
    refresh();

    // Every key is a test subject here, and that includes the volume
    // shortcuts: "0", "-" and "+" must light up, not mute or remix the game.
    FlxG.sound.muteKeys = [];
    FlxG.sound.volumeDownKeys = [];
    FlxG.sound.volumeUpKeys = [];

    // The same events PlayState judges notes from, so the arrival times shown
    // here are the ones gameplay works with.
    FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    FlxG.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyUp);

    // The EXIT button also answers to a mouse, which needs its pointer.
    cursorWasVisible = FlxG.mouse.visible;
    FlxG.mouse.visible = !TouchlessUI.isActive();
  }

  override function update(elapsed:Float):Void
  {
    final time:Float = clock();
    pollGamepads(time);
    pollTouches(time);
    logic.endFrame();

    if (systemBackPressed() || logic.updateExit(elapsed, mouseOnExit())) leave();

    showExitProgress();
    if (logic.revision != shownRevision || connectedPads != shownPads) refresh();

    super.update(elapsed);
  }

  function onKeyDown(event:KeyboardEvent):Void
  {
    // A held key repeats; the model keeps the first press and ignores the rest.
    logic.press(InputTestLogic.KEYBOARD, event.keyCode, clock(), backKeys.indexOf(event.keyCode) != -1);
  }

  function onKeyUp(event:KeyboardEvent):Void
  {
    logic.release(InputTestLogic.KEYBOARD, event.keyCode, clock());
  }

  /** Releases never arrive while the window is in the background, so nothing may stay "held". */
  override public function onFocusLost():Void
  {
    super.onFocusLost();
    logic.drop();
  }

  function pollGamepads(time:Float):Void
  {
    var pads:Int = 0;
    logic.beginPoll(InputTestLogic.GAMEPAD);
    for (index in 0...MAX_GAMEPADS)
    {
      final pad:FlxGamepad = FlxG.gamepads.getByID(index);
      if (pad == null || !pad.connected) continue;
      pads++;
      for (button in PAD_BUTTONS)
      {
        if (!pad.checkStatus(button, PRESSED)) continue;
        final id:Int = button;
        // The buttons the default pad map binds to Back.
        logic.poll(InputTestLogic.GAMEPAD, index * PAD_STRIDE + id, time, button == FlxGamepadInputID.B || button == FlxGamepadInputID.BACK);
      }
    }
    logic.endPoll(InputTestLogic.GAMEPAD, time);
    connectedPads = pads;
  }

  function pollTouches(time:Float):Void
  {
    for (slot in 0...TOUCH_MARKERS)
      markerUsed[slot] = false;

    logic.beginPoll(InputTestLogic.TOUCH);
    #if FLX_TOUCH
    if (FlxG.touches != null)
    {
      for (touch in FlxG.touches.list)
      {
        if (touch == null || !touch.pressed) continue;
        final slot:Int = logic.poll(InputTestLogic.TOUCH, touch.touchPointID, time, insideExit(touch.screenX, touch.screenY));
        if (slot < 0 || slot >= TOUCH_MARKERS) continue;
        markerUsed[slot] = true;
        placeMarker(slot, touch.screenX, touch.screenY);
      }
    }
    #end
    logic.endPoll(InputTestLogic.TOUCH, time);

    for (slot in 0...TOUCH_MARKERS)
    {
      if (markerUsed[slot]) continue;
      markerRows[slot].visible = markerColumns[slot].visible = markerLabels[slot].visible = false;
    }
  }

  function placeMarker(slot:Int, x:Float, y:Float):Void
  {
    final row:FlxSprite = markerRows[slot];
    final column:FlxSprite = markerColumns[slot];
    final number:FlxText = markerLabels[slot];
    row.setPosition(0, y - 1);
    column.setPosition(x - 1, 0);
    // Beside the finger rather than under it, and never off the screen.
    number.setPosition(Math.max(0, Math.min(FlxG.width - 44, x + 16)), Math.max(0, y - 38));
    row.visible = column.visible = number.visible = true;
  }

  inline function insideExit(x:Float, y:Float):Bool
  {
    return exitZone != null
      && x >= exitZone.x
      && x < exitZone.x + exitZone.width
      && y >= exitZone.y
      && y < exitZone.y + exitZone.height;
  }

  /**
   * A mouse holding EXIT. Some targets report the first finger as the mouse
   * too; the touch poll already knows whether that finger is alone, so the
   * mouse only counts while no touch is down.
   */
  function mouseOnExit():Bool
  {
    #if FLX_MOUSE
    final mouseAlone:Bool = FlxG.mouse != null && logic.held(InputTestLogic.TOUCH) == 0;
    return mouseAlone && FlxG.mouse.pressed && insideExit(FlxG.mouse.screenX, FlxG.mouse.screenY);
    #else
    return false;
    #end
  }

  /** Android's Back (button, gesture or TV remote) is the system asking, not a test input. */
  function systemBackPressed():Bool
  {
    var pressed:Bool = TouchlessUI.isBackPressed();
    #if android
    pressed = pressed || FlxG.android.justPressed.BACK;
    #end
    return pressed;
  }

  /** Escape always works, and so does whatever the player bound to Back. */
  function exitKeys():Array<Int>
  {
    final keys:Array<Int> = [FlxKey.ESCAPE];
    final bound:Array<FlxKey> = ClientPrefs.keyBinds.get('back');
    if (bound != null)
    {
      for (key in bound)
      {
        final code:Int = key;
        // NONE and the hardware-button binds are negative: no key event carries them.
        if (code > 0 && keys.indexOf(code) == -1) keys.push(code);
      }
    }
    return keys;
  }

  function inputName(device:Int, code:Int, slot:Int):String
  {
    return switch (device)
    {
      case InputTestLogic.KEYBOARD: keyName(code);
      case InputTestLogic.GAMEPAD: padButtonName(code);
      default: 'Finger ' + (slot + 1);
    }
  }

  function keyName(code:Int):String
  {
    final name:String = InputFormatter.getKeyName(code);
    // Flixel has no name for this key, which also means it cannot be bound.
    return name == '---' ? 'Key ' + code : name;
  }

  function padButtonName(code:Int):String
  {
    final index:Int = Std.int(code / PAD_STRIDE);
    final id:FlxGamepadInputID = code % PAD_STRIDE;
    final pad:FlxGamepad = FlxG.gamepads.getByID(index);
    // What this model of pad prints on the button: "a", "lb", "ls-left".
    var name:String = (pad != null && pad.connected) ? pad.getInputLabel(id) : null;
    if (name == null) name = id.toString();
    if (name == null) name = 'button ' + (code % PAD_STRIDE);
    name = name.toUpperCase();
    return index == 0 ? name : 'P' + (index + 1) + ' ' + name;
  }

  /** Rebuilds the text. Only called when an input or a pad changed, never per frame. */
  function refresh():Void
  {
    shownRevision = logic.revision;
    shownPads = connectedPads;

    for (device in 0...InputTestLogic.DEVICES)
    {
      final names:String = logic.heldNames(device, namer, nameColumns, NAME_ROWS);
      final header:String = InputTestLogic.deviceName(device) + '\n' + deviceStatus(device) + '\n\n' + logic.counters(device) + '\n\n';
      deviceTexts[device].text = header + (names.length > 0 ? names : idleText(device));
    }

    final frameMs:Float = FlxG.updateFramerate > 0 ? 1000 / FlxG.updateFramerate : 0;
    timingText.text = 'PRESS TIMING\n' + logic.timing(namer, frameMs) + '\n\n' + TIMING_NOTE;

    final history:String = logic.history(namer);
    historyText.text = 'LATEST FIRST\n' + (history.length > 0 ? history : 'nothing pressed yet');
  }

  function deviceStatus(device:Int):String
  {
    return switch (device)
    {
      case InputTestLogic.KEYBOARD: 'timed as events arrive';
      case InputTestLogic.GAMEPAD if (connectedPads == 0): 'none connected';
      case InputTestLogic.GAMEPAD: connectedPads + (connectedPads == 1 ? ' pad' : ' pads') + ', read once per frame';
      default: 'read once per frame';
    }
  }

  function idleText(device:Int):String
  {
    return switch (device)
    {
      case InputTestLogic.KEYBOARD: 'press some keys';
      case InputTestLogic.GAMEPAD: connectedPads == 0 ? 'plug in a gamepad' : 'press some buttons';
      default: 'put fingers on the screen';
    }
  }

  function showExitProgress():Void
  {
    final progress:Float = logic.exitProgress();
    exitBarBack.visible = exitBar.visible = progress > 0;
    if (progress <= 0) return;
    exitBar.setGraphicSize(Std.int(Math.max(1, EXIT_BAR_WIDTH * progress)), EXIT_BAR_HEIGHT);
    exitBar.updateHitbox();
  }

  function layout():Void
  {
    final left:Float = ScreenLayout.contentLeft(FlxG.width) + MARGIN;
    final width:Int = Std.int(Math.max(480, Math.min(CONTENT_WIDTH, FlxG.width - MARGIN * 2)));

    titleText.setPosition(left, 10);
    introText.fieldWidth = width - EXIT_WIDTH - 24;
    introText.setPosition(left, 44);

    place(exitPanel, left + width - EXIT_WIDTH, 12, EXIT_WIDTH, EXIT_HEIGHT);
    exitText.fieldWidth = EXIT_WIDTH;
    exitText.setPosition(exitPanel.x, exitPanel.y + 7);
    // Fingers need more room than the art gives them (same rule as TouchTarget).
    exitZone = HoldToConfirmLogic.grow(exitPanel.x, exitPanel.y, EXIT_WIDTH, EXIT_HEIGHT);

    final column:Int = Std.int((width - PANEL_GAP * (InputTestLogic.DEVICES - 1)) / InputTestLogic.DEVICES);
    // A text field keeps a 2 px gutter on each side. Wrapping the names here,
    // instead of letting the field do it, is what bounds them to NAME_ROWS lines.
    nameColumns = Std.int((column - PANEL_PADDING * 2 - 4) / (DEVICE_FONT * FONT_ADVANCE));
    for (device in 0...InputTestLogic.DEVICES)
    {
      final x:Float = left + device * (column + PANEL_GAP);
      place(devicePanels[device], x, DEVICE_TOP, column, DEVICE_HEIGHT);
      deviceTexts[device].fieldWidth = column - PANEL_PADDING * 2;
      deviceTexts[device].setPosition(x + PANEL_PADDING, DEVICE_TOP + 10);
    }

    hintText.fieldWidth = FlxG.width - 20;
    hintText.setPosition(10, FlxG.height - hintText.height - 10);

    final timingTop:Int = DEVICE_TOP + DEVICE_HEIGHT + PANEL_GAP;
    final timingHeight:Int = Std.int(Math.max(120, hintText.y - 22 - timingTop));
    final half:Int = Std.int(width / 2);
    place(timingPanel, left, timingTop, width, timingHeight);
    timingText.fieldWidth = half - PANEL_PADDING - 6;
    timingText.setPosition(left + PANEL_PADDING, timingTop + 10);
    historyText.fieldWidth = half - PANEL_PADDING - 6;
    historyText.setPosition(left + half + 6, timingTop + 10);

    final barX:Float = (FlxG.width - EXIT_BAR_WIDTH) / 2;
    final barY:Float = hintText.y - 14;
    place(exitBarBack, barX, barY, EXIT_BAR_WIDTH, EXIT_BAR_HEIGHT);
    exitBar.setPosition(barX, barY);

    for (slot in 0...TOUCH_MARKERS)
    {
      markerRows[slot].setGraphicSize(FlxG.width, 2);
      markerRows[slot].updateHitbox();
      markerColumns[slot].setGraphicSize(2, FlxG.height);
      markerColumns[slot].updateHitbox();
    }
  }

  function leave():Void
  {
    if (leaving) return;
    leaving = true;
    FlxG.sound.play(Paths.sound('cancelMenu'));
    if (fromOptions) FlxG.switchState(() -> new options.OptionsState());
    else
      FlxG.switchState(MainMenuState.new);
  }

  override function destroy():Void
  {
    FlxG.stage.removeEventListener(KeyboardEvent.KEY_DOWN, onKeyDown);
    FlxG.stage.removeEventListener(KeyboardEvent.KEY_UP, onKeyUp);
    FlxG.sound.muteKeys = TitleState.muteKeys;
    FlxG.sound.volumeDownKeys = TitleState.volumeDownKeys;
    FlxG.sound.volumeUpKeys = TitleState.volumeUpKeys;
    // The Options list has no pointer (NoteOffsetState hides it on the way back
    // too); any other screen gets it back the way it had it.
    FlxG.mouse.visible = !fromOptions && cursorWasVisible;
    super.destroy();
  }

  function label(size:Int, text:String, align:FlxTextAlign = LEFT):FlxText
  {
    final field:FlxText = new FlxText(0, 0, 0, text, size);
    field.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, align, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    field.borderSize = 1;
    add(field);
    return field;
  }

  function panel(color:FlxColor = 0xC0000000):FlxSprite
  {
    final sprite:FlxSprite = new FlxSprite();
    sprite.makeGraphic(1, 1, color);
    add(sprite);
    return sprite;
  }

  function marker(color:FlxColor):FlxSprite
  {
    final sprite:FlxSprite = panel(color);
    sprite.alpha = 0.7;
    sprite.visible = false;
    return sprite;
  }

  static function place(sprite:FlxSprite, x:Float, y:Float, width:Int, height:Int):Void
  {
    sprite.setPosition(x, y);
    sprite.setGraphicSize(width, height);
    sprite.updateHitbox();
  }

  /** Milliseconds from the most precise clock the target has. */
  static function preciseTime():Float
  {
    #if (js && html5)
    return js.Browser.window.performance.now();
    #elseif (lime_cffi && !macro)
    // `haxe.Timer.stamp()` is whole milliseconds on native Lime; the counter is not.
    final frequency:Float = lime.system.System.getPerformanceFrequency();
    if (frequency > 0) return lime.system.System.getPerformanceCounter() / frequency * 1000;
    return haxe.Timer.stamp() * 1000;
    #else
    return haxe.Timer.stamp() * 1000;
    #end
  }
}
