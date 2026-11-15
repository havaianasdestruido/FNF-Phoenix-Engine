package backend;

/** Turns a device, an input code and a slot into the label a player reads. */
typedef InputNamer = (device:Int, code:Int, slot:Int) -> String;

/** One input the game currently sees as held down. */
class InputTestHeld
{
  /** `InputTestLogic.KEYBOARD`, `GAMEPAD` or `TOUCH`. */
  public var device:Int = 0;

  /** Key code, gamepad button code or touch id: whatever the device reports. */
  public var code:Int = 0;

  /** Lowest index no other held input of the device uses ("Finger 1" is slot 0). */
  public var slot:Int = 0;

  /** When the press was seen, in milliseconds on the caller's clock. */
  public var time:Float = 0;

  /** Frame the press landed in; see `InputTestLogic.endFrame`. */
  public var frame:Int = 0;

  /** Part of the leave gesture: a Back key, a Back button, the on-screen exit. */
  public var exit:Bool = false;

  /** Still down in the poll that is running; see `InputTestLogic.beginPoll`. */
  public var seen:Bool = true;

  public function new() {}
}

/** One press or release kept in the short history. */
class InputTestEvent
{
  /** `true` for a press, `false` for a release. */
  public var down:Bool = false;

  public var device:Int = 0;
  public var code:Int = 0;
  public var slot:Int = 0;

  /** Press: milliseconds since the press before it, `-1` for the very first. Release: how long it was held. */
  public var span:Float = -1;

  /** Inputs held on every device right after the event. */
  public var held:Int = 0;

  public function new() {}
}

/**
 * Renderer-free bookkeeping behind `states.InputTestState` (`phoenix://input`).
 *
 * The page answers two questions a rhythm game player actually has: "how many
 * of my keys, buttons or fingers does the game see *at the same time*?" and
 * "how far apart did my presses arrive?". A keyboard that drops the third key
 * of a chord shows a held count stuck at 2; a phone that tracks two fingers
 * shows a touch count that never reaches 3.
 *
 * This class only counts and measures. It knows nothing about Flixel, OpenFL
 * or Lime, so `haxe --interp` can drive it in CI with a scripted clock:
 *
 * - `press` / `release` take events as they arrive (the keyboard listeners).
 * - `beginPoll` / `poll` / `endPoll` diff a device that is read once per frame
 *   (gamepads, touches), which stays correct when a frame is skipped.
 * - `endFrame` marks the frame boundary, which is what turns arrival times
 *   into the two numbers of the poll-rate audit (TODO.md §15): how many presses
 *   landed inside one frame, and how many taps went down and came back up
 *   between two frames, where a once-per-frame read never sees them held.
 * - `updateExit` runs the leave gesture. Every input is a test subject here,
 *   so leaving is a hold on a Back input *with nothing else held on that
 *   device*: tapping Escape or B just shows them, and a chord that happens to
 *   contain B cannot throw the player out.
 *
 * Nothing is written anywhere: no preference, no bind, no file.
 */
class InputTestLogic
{
  public static inline var KEYBOARD:Int = 0;
  public static inline var GAMEPAD:Int = 1;
  public static inline var TOUCH:Int = 2;

  /** Number of device classes; valid devices are `0...DEVICES`. */
  public static inline var DEVICES:Int = 3;

  /** How many presses and releases the history keeps. */
  public static inline var DEFAULT_HISTORY:Int = 12;

  /** Seconds a Back input has to be held, alone, before the page closes. */
  public static inline var EXIT_HOLD_SECONDS:Float = 1.0;

  /** "No value yet" for the millisecond readouts. */
  public static inline var NONE:Float = -1;

  /** About three years. Nothing here lasts that long, and past it the tenths of a second no longer fit an Int. */
  static inline var LONGEST_MS:Float = 1e11;

  /** Grows whenever something a renderer shows has changed; redraw text only then. */
  public var revision(default, null):Int = 0;

  /** Milliseconds between the latest press and the one before it, `NONE` until two presses exist. */
  public var lastGap(default, null):Float = NONE;

  /** Milliseconds the most recently released input was held, `NONE` until a release. */
  public var lastHold(default, null):Float = NONE;

  /** Largest number of inputs held together during the current (or most recent) chord. */
  public var chordSize(default, null):Int = 0;

  /** Milliseconds from the first press of that chord to the press that made it that large. */
  public var chordSpread(default, null):Float = 0;

  /** Presses seen since the last `endFrame`. */
  public var framePresses(default, null):Int = 0;

  /** Most presses that ever landed inside a single frame. */
  public var maxFramePresses(default, null):Int = 0;

  /** Inputs that went down and came back up inside one frame: a once-per-frame poll never sees them held. */
  public var shortTaps(default, null):Int = 0;

  var heldInputs:Array<InputTestHeld> = [];
  var spare:Array<InputTestHeld> = [];
  var heldCount:Array<Int> = [for (_ in 0...DEVICES) 0];
  var exitCount:Array<Int> = [for (_ in 0...DEVICES) 0];
  var peakCount:Array<Int> = [for (_ in 0...DEVICES) 0];
  var pressCount:Array<Int> = [for (_ in 0...DEVICES) 0];
  var totalHeld:Int = 0;

  var frame:Int = 0;
  var lastTime:Float = 0;
  var lastPressTime:Float = 0;
  var chordStart:Float = 0;

  var hasPress:Bool = false;
  var pressDevice:Int = 0;
  var pressCode:Int = 0;
  var pressSlot:Int = 0;
  var hasRelease:Bool = false;
  var releaseDevice:Int = 0;
  var releaseCode:Int = 0;
  var releaseSlot:Int = 0;

  var events:Array<InputTestEvent> = [];
  var eventNext:Int = 0;
  var eventCount:Int = 0;

  var exitHeldFor:Float = 0;
  var exitDone:Bool = false;

  /**
   * Starts with nothing held, no readings and an empty history.
   *
   * @param history how many presses and releases to remember (at least one).
   */
  public function new(history:Int = DEFAULT_HISTORY)
  {
    for (_ in 0...(history < 1 ? 1 : history))
      events.push(new InputTestEvent());
  }

  /* ------------------------------------------------------------------ */
  /* Feeding inputs                                                     */
  /* ------------------------------------------------------------------ */
  /**
   * Records an input going down.
   *
   * @param device `KEYBOARD`, `GAMEPAD` or `TOUCH`.
   * @param code   the device's own id for the input.
   * @param time   milliseconds on any clock, as long as every call uses the same one.
   * @param exit   whether this input belongs to the leave gesture.
   * @return `false` when nothing was recorded: an unknown device, or an input
   *         that is already held (keyboard auto-repeat sends the same key again).
   */
  public function press(device:Int, code:Int, time:Float, exit:Bool = false):Bool
  {
    if (!valid(device) || indexOf(device, code) != -1) return false;
    time = clean(time);

    final input:InputTestHeld = spare.length > 0 ? spare.pop() : new InputTestHeld();
    input.device = device;
    input.code = code;
    input.slot = freeSlot(device);
    input.time = time;
    input.frame = frame;
    input.exit = exit;
    input.seen = true;
    heldInputs.push(input);

    heldCount[device]++;
    if (exit) exitCount[device]++;
    pressCount[device]++;
    totalHeld++;
    if (heldCount[device] > peakCount[device]) peakCount[device] = heldCount[device];

    lastGap = hasPress ? Math.max(0, time - lastPressTime) : NONE;
    lastPressTime = time;
    hasPress = true;
    pressDevice = device;
    pressCode = code;
    pressSlot = input.slot;

    if (totalHeld == 1)
    {
      // Everything had been released: this press starts a new chord.
      chordStart = time;
      chordSize = 1;
      chordSpread = 0;
    } else if (totalHeld > chordSize)
    {
      chordSize = totalHeld;
      chordSpread = Math.max(0, time - chordStart);
    }

    framePresses++;
    if (framePresses > maxFramePresses) maxFramePresses = framePresses;

    remember(true, input, lastGap);
    revision++;
    return true;
  }

  /**
   * Records an input coming back up.
   *
   * @return milliseconds it was held, or `NONE` when it was not held (a key
   *         that went down before the page opened, a release reported twice).
   */
  public function release(device:Int, code:Int, time:Float):Float
  {
    final index:Int = valid(device) ? indexOf(device, code) : -1;
    if (index == -1) return NONE;
    time = clean(time);

    final input:InputTestHeld = heldInputs[index];
    forget(index);

    final heldFor:Float = Math.max(0, time - input.time);
    if (input.frame == frame) shortTaps++;
    lastHold = heldFor;
    hasRelease = true;
    releaseDevice = input.device;
    releaseCode = input.code;
    releaseSlot = input.slot;

    remember(false, input, heldFor);
    spare.push(input);
    revision++;
    return heldFor;
  }

  /**
   * Forgets every held input without counting it as a release: the window
   * lost focus, so the real releases will never arrive. Peaks, press counts,
   * timings and the history are facts and stay.
   *
   * @return how many inputs were dropped.
   */
  public function drop():Int
  {
    final dropped:Int = heldInputs.length;
    while (heldInputs.length > 0)
    {
      final input:InputTestHeld = heldInputs[heldInputs.length - 1];
      forget(heldInputs.length - 1);
      spare.push(input);
    }
    if (dropped > 0) revision++;
    return dropped;
  }

  /**
   * Starts one read of a device that reports state instead of events. Follow
   * it with a `poll` for every input that is down and one `endPoll`.
   */
  public function beginPoll(device:Int):Void
  {
    for (input in heldInputs)
      if (input.device == device) input.seen = false;
  }

  /**
   * Reports an input that is down in the current poll; a new one counts as a press.
   *
   * @return the input's slot, or `-1` for an unknown device.
   */
  public function poll(device:Int, code:Int, time:Float, exit:Bool = false):Int
  {
    if (!valid(device)) return -1;
    var index:Int = indexOf(device, code);
    if (index == -1)
    {
      press(device, code, time, exit);
      index = heldInputs.length - 1;
    }
    final input:InputTestHeld = heldInputs[index];
    input.seen = true;
    return input.slot;
  }

  /**
   * Ends a poll: whatever was held on the device and not reported is released.
   *
   * @return how many inputs were released.
   */
  public function endPoll(device:Int, time:Float):Int
  {
    var released:Int = 0;
    var index:Int = heldInputs.length;
    while (index-- > 0)
    {
      final input:InputTestHeld = heldInputs[index];
      if (input.device != device || input.seen) continue;
      release(device, input.code, time);
      released++;
    }
    return released;
  }

  /** Marks a frame boundary: call once per game update, after the frame's inputs. */
  public function endFrame():Void
  {
    frame++;
    framePresses = 0;
  }

  /* ------------------------------------------------------------------ */
  /* Leaving                                                            */
  /* ------------------------------------------------------------------ */
  /**
   * Advances the leave gesture by one frame.
   *
   * The hold counts while some device has an exit input down and nothing else
   * down, or while `pointerHeld` says a mouse is pressing the on-screen exit.
   * Anything else restarts it.
   *
   * @param elapsed     seconds since the previous frame.
   * @param pointerHeld a pointer this class does not track is holding the exit button.
   * @return `true` exactly once, on the frame the page should close.
   */
  public function updateExit(elapsed:Float, pointerHeld:Bool = false):Bool
  {
    if (exitDone) return false;
    if (Math.isNaN(elapsed) || elapsed < 0) elapsed = 0;

    if (!pointerHeld && !exitHeld())
    {
      exitHeldFor = 0;
      return false;
    }

    exitHeldFor += elapsed;
    if (exitHeldFor < EXIT_HOLD_SECONDS) return false;
    exitDone = true;
    return true;
  }

  /** How far the leave gesture is, from 0 (not holding) to 1 (closing). */
  public function exitProgress():Float
    return Math.min(1, exitHeldFor / EXIT_HOLD_SECONDS);

  function exitHeld():Bool
  {
    for (device in 0...DEVICES)
      if (exitCount[device] > 0 && exitCount[device] == heldCount[device]) return true;
    return false;
  }

  /* ------------------------------------------------------------------ */
  /* Reading the counters                                               */
  /* ------------------------------------------------------------------ */
  /** Inputs of one device held right now. */
  public function held(device:Int):Int
    return valid(device) ? heldCount[device] : 0;

  /** Most inputs of one device that were ever held together. */
  public function peak(device:Int):Int
    return valid(device) ? peakCount[device] : 0;

  /** Presses counted for one device (repeats of a held key are not presses). */
  public function presses(device:Int):Int
    return valid(device) ? pressCount[device] : 0;

  /** How many events the history holds right now. */
  public function historyLength():Int
    return eventCount;

  /**
   * One remembered event; index 0 is the most recent.
   *
   * @return `null` outside `0...historyLength()`.
   */
  public function historyAt(index:Int):Null<InputTestEvent>
  {
    if (index < 0 || index >= eventCount) return null;
    return events[(eventNext - 1 - index + events.length * 2) % events.length];
  }

  /* ------------------------------------------------------------------ */
  /* Text                                                               */
  /* ------------------------------------------------------------------ */
  /** Section title for a device. */
  public static function deviceName(device:Int):String
  {
    return switch (device)
    {
      case KEYBOARD: 'KEYBOARD';
      case GAMEPAD: 'GAMEPAD';
      case TOUCH: 'TOUCH';
      default: 'UNKNOWN';
    }
  }

  /**
   * A duration with one decimal: `12.4 ms`, `0.0 ms` for inputs that arrived
   * together, seconds from ten seconds up, `-` when there is nothing to show
   * (no reading yet, or one so long that it can only be a clock glitch).
   */
  public static function formatMs(ms:Float):String
  {
    if (Math.isNaN(ms) || ms < 0 || ms >= LONGEST_MS) return '-';
    // 9999.95 is where one decimal would round up to a fifth digit.
    if (ms >= 9999.95) return oneDecimal(ms / 1000) + ' s';
    return oneDecimal(ms) + ' ms';
  }

  static function oneDecimal(value:Float):String
  {
    final tenths:Int = Math.round(value * 10);
    return Std.int(tenths / 10) + '.' + (tenths % 10);
  }

  /** The three counters of one device, as aligned rows for a monospace font. */
  public function counters(device:Int):String
  {
    final heldRows:String = 'held now     ' + number(held(device)) + '\nmost at once ' + number(peak(device));
    return heldRows + '\npresses      ' + number(presses(device));
  }

  /**
   * The names of what is held on a device, oldest press first; empty when
   * nothing is. With `columns` set they are laid out for a monospace panel:
   * lines of at most `columns` characters and at most `rows` of them, and the
   * names that do not fit are summed up as `+N more`, so a full-rollover
   * keyboard cannot push the list out of its panel.
   *
   * @param columns characters per line; 0 or less puts every name on one line.
   * @param rows    lines available when `columns` is set; one is always used.
   */
  public function heldNames(device:Int, name:InputNamer, columns:Int = 0, rows:Int = 1, separator:String = '  '):String
  {
    final total:Int = held(device);
    if (total == 0) return '';

    final labels:Array<String> = [];
    for (input in heldInputs)
      if (input.device == device) labels.push(name(input.device, input.code, input.slot));
    if (columns <= 0) return labels.join(separator);

    // Take names off the end until the rest, and the "+N more" that stands in
    // for them, fits. With no name left the summary alone always does.
    var shown:Int = total;
    var text:Null<String> = wrap(labels, shown, null, columns, rows, separator);
    while (text == null)
    {
      shown--;
      text = wrap(labels, shown, '+' + (total - shown) + ' more', columns, rows, separator);
    }
    return text;
  }

  /**
   * Fills lines greedily with the first `count` labels and an optional last
   * piece. A piece wider than a line gets a line of its own.
   *
   * @return `null` when that takes more than `rows` lines.
   */
  static function wrap(labels:Array<String>, count:Int, last:Null<String>, columns:Int, rows:Int, separator:String):Null<String>
  {
    var text:String = '';
    var lineLength:Int = 0;
    var lines:Int = 1;
    for (index in 0...(last == null ? count : count + 1))
    {
      final piece:String = index < count ? labels[index] : last;
      if (lineLength > 0 && lineLength + separator.length + piece.length > columns)
      {
        if (++lines > rows) return null;
        text += '\n';
        lineLength = 0;
      }
      if (lineLength > 0)
      {
        text += separator;
        lineLength += separator.length;
      }
      text += piece;
      lineLength += piece.length;
    }
    return text;
  }

  /**
   * The press-timing readout: five aligned rows.
   *
   * @param frameMs length of one game update in milliseconds, for the row that
   *                explains what "inside one frame" means; 0 or less hides it.
   */
  public function timing(name:InputNamer, frameMs:Float = 0):String
  {
    var press:String = '-';
    if (hasPress) press = name(pressDevice, pressCode, pressSlot) + (lastGap < 0 ? '  (first press)' : '  +' + formatMs(lastGap));

    final release:String = hasRelease ? name(releaseDevice, releaseCode, releaseSlot) + '  held ' + formatMs(lastHold) : '-';

    var chord:String = '-';
    if (chordSize == 1) chord = '1 at once';
    else if (chordSize > 1) chord = chordSize + ' at once, built in ' + formatMs(chordSpread);

    var perFrame:String = maxFramePresses + (maxFramePresses == 1 ? ' press' : ' presses') + ' in one frame';
    if (!Math.isNaN(frameMs) && frameMs > 0) perFrame += ' (' + formatMs(frameMs) + ')';

    final rows:String = 'last press     ' + press + '\nlast release   ' + release + '\nlast chord     ' + chord;
    return rows + '\nmost per frame ' + perFrame + '\nshort taps     ' + shortTaps + ' down and up inside one frame';
  }

  /** The remembered presses and releases, most recent first, one per row. */
  public function history(name:InputNamer):String
  {
    var text:String = '';
    for (index in 0...eventCount)
    {
      final event:InputTestEvent = historyAt(index);
      if (index > 0) text += '\n';
      text += (event.down ? 'down  ' : 'up    ') + StringTools.rpad(name(event.device, event.code, event.slot), ' ', 12) + ' ';
      if (event.down) text += StringTools.rpad(event.span < 0 ? 'first' : '+' + formatMs(event.span), ' ', 11) + ' ' + event.held + ' held';
      else
        text += 'held ' + formatMs(event.span);
    }
    return text;
  }

  static inline function number(value:Int):String
    return StringTools.lpad(Std.string(value), ' ', 4);

  /* ------------------------------------------------------------------ */
  /* Internals                                                          */
  /* ------------------------------------------------------------------ */
  static inline function valid(device:Int):Bool
    return device >= 0 && device < DEVICES;

  /** A clock that hiccups (NaN) must not poison every later difference. */
  function clean(time:Float):Float
  {
    if (Math.isNaN(time)) return lastTime;
    lastTime = time;
    return time;
  }

  function indexOf(device:Int, code:Int):Int
  {
    for (index in 0...heldInputs.length)
    {
      final input:InputTestHeld = heldInputs[index];
      if (input.device == device && input.code == code) return index;
    }
    return -1;
  }

  function freeSlot(device:Int):Int
  {
    var slot:Int = 0;
    var taken:Bool = true;
    while (taken)
    {
      taken = false;
      for (input in heldInputs)
      {
        if (input.device == device && input.slot == slot)
        {
          taken = true;
          slot++;
          break;
        }
      }
    }
    return slot;
  }

  /** Removes a held input in place, keeping press order and the counters. */
  function forget(index:Int):Void
  {
    final input:InputTestHeld = heldInputs[index];
    for (next in index...heldInputs.length - 1)
      heldInputs[next] = heldInputs[next + 1];
    heldInputs.pop();
    heldCount[input.device]--;
    if (input.exit) exitCount[input.device]--;
    totalHeld--;
  }

  function remember(down:Bool, input:InputTestHeld, span:Float):Void
  {
    final event:InputTestEvent = events[eventNext];
    event.down = down;
    event.device = input.device;
    event.code = input.code;
    event.slot = input.slot;
    event.span = span;
    event.held = totalHeld;
    eventNext = (eventNext + 1) % events.length;
    if (eventCount < events.length) eventCount++;
  }
}
