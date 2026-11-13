package backend;

/** Axis-aligned rectangle in game/world units. */
typedef TouchRect = {
  var x:Float;
  var y:Float;
  var width:Float;
  var height:Float;
}

/** One frame of input for a guarded action, from any combination of pointers and keys. */
typedef HoldInput = {
  /** Something is held down on the action right now. */
  var pressed:Bool;
  /** A press started on the action this frame. */
  var justPressed:Bool;
  /** A press ended this frame (possibly after dragging away). */
  var justReleased:Bool;
  /** A pointer is over the action, or the action has keyboard/gamepad focus. */
  var over:Bool;
  /** A fresh press happened somewhere else; cancels an armed second confirmation. */
  var pressedOutside:Bool;
}

/** Mutable state of one hold-to-confirm guard. */
typedef HoldState = {
  /** A hold is in progress (hold mode) or a confirmation is armed (confirm mode). */
  var active:Bool;
  /** Seconds the current press has been held. */
  var heldFor:Float;
  /** Waiting for the second press. */
  var armed:Bool;
  /** Seconds left before an armed confirmation expires. */
  var armedLeft:Float;
  /** The first press has not been released yet; ignore repeats of the same press. */
  var needRelease:Bool;
  /** The action already fired; guards are one-shot until `reset()` is called. */
  var done:Bool;
}

/**
 * Renderer-free rules shared by `objects.TouchTarget` / `objects.HoldToConfirm`
 * and their Haxe specs. No Flixel, OpenFL or Lime imports: this module can be
 * interpreted by `haxe --interp` in CI without the game's haxelibs.
 *
 * Destructive actions (deleting a mod/save/chart, leaving a song, resetting
 * settings) must never fire on one accidental tap. Two gestures are supported:
 *
 * - `MODE_HOLD`: press and keep holding for `holdSeconds`; releasing, dragging
 *   off the target or losing keyboard focus cancels the hold.
 * - `MODE_CONFIRM`: press once to arm, release, then press again inside a short
 *   window. A press elsewhere or a timeout cancels it.
 *
 * `ClientPrefs.holdToConfirm` picks the mode; turning it off never restores
 * single-tap behaviour, it switches to the second-confirmation gesture.
 */
class HoldToConfirmLogic
{
  /** Default hold length, also used when a saved preference is out of range. */
  public static inline var DEFAULT_HOLD_SECONDS:Float = 0.65;
  /** How long the "press again to confirm" window stays open. */
  public static inline var DEFAULT_CONFIRM_WINDOW:Float = 3.0;

  /**
   * Minimum tap target, in 1280x720 game units. 88 units is ~44 dp on a 2x
   * phone display; small menu glyphs are padded up to at least this size by
   * an invisible sprite, so no art asset has to change.
   */
  public static inline var MIN_TOUCH_SIZE:Float = 88;
  /** Extra room added around the *visual* bounds before the minimum is applied. */
  public static inline var TOUCH_PADDING:Float = 12;

  public static inline var MODE_HOLD:Int = 0;
  public static inline var MODE_CONFIRM:Int = 1;

  public static inline var NONE:Int = 0;
  /** First press of a second-confirmation gesture was accepted. */
  public static inline var ARMED:Int = 1;
  /** The action may run now. */
  public static inline var CONFIRMED:Int = 2;
  /** A hold or armed confirmation was abandoned. */
  public static inline var CANCELLED:Int = 3;

  /** Clamps a saved hold length; rejects NaN/Infinity and absurd values. */
  public static function holdSeconds(?value:Float):Float
  {
    if (value == null || value != value || value < 0.25 || value > 5)
      return DEFAULT_HOLD_SECONDS;
    return value;
  }

  /** Clamps the second-confirmation window. */
  public static function confirmWindow(?value:Float):Float
  {
    if (value == null || value != value || value < 0.5 || value > 15)
      return DEFAULT_CONFIRM_WINDOW;
    return value;
  }

  /**
   * Grows a visual bounding box into a touch target, centred on the art.
   * The visual sprite is never resized: callers draw an invisible `FlxSprite`
   * over these bounds instead. Negative/NaN sizes collapse to zero first.
   *
   * @param x      visual left edge
   * @param y      visual top edge
   * @param width  visual width
   * @param height visual height
   */
  public static function grow(x:Float, y:Float, width:Float, height:Float,
      ?minWidth:Float = MIN_TOUCH_SIZE, ?minHeight:Float = MIN_TOUCH_SIZE,
      ?padding:Float = TOUCH_PADDING):TouchRect
  {
    if (x == null || x != x) x = 0;
    if (y == null || y != y) y = 0;
    if (width == null || width != width || width < 0) width = 0;
    if (height == null || height != height || height < 0) height = 0;
    if (minWidth == null || minWidth != minWidth || minWidth < 1) minWidth = 1;
    if (minHeight == null || minHeight != minHeight || minHeight < 1) minHeight = 1;
    if (padding == null || padding != padding || padding < 0) padding = 0;

    var w:Float = Math.max(width + padding * 2, minWidth);
    var h:Float = Math.max(height + padding * 2, minHeight);
    return {x: x + width * 0.5 - w * 0.5, y: y + height * 0.5 - h * 0.5, width: w, height: h};
  }

  public static function idle():HoldInput
    return {pressed: false, justPressed: false, justReleased: false, over: false, pressedOutside: false};

  public static function newState():HoldState
    return {active: false, heldFor: 0, armed: false, armedLeft: 0, needRelease: false, done: false};

  /** Clears a guard completely, including its one-shot latch. */
  public static function reset(state:HoldState):Void
  {
    state.active = false;
    state.heldFor = 0;
    state.armed = false;
    state.armedLeft = 0;
    state.needRelease = false;
    state.done = false;
  }

  /**
   * Combines two input sources (typically a pointer sample and a keyboard /
   * gamepad / virtual-pad sample) into one frame. A press outside the target
   * only cancels an armed confirmation when nothing else has the action in
   * focus, so a stray second finger cannot void a keyboard confirmation.
   */
  public static function merge(a:HoldInput, b:HoldInput):HoldInput
  {
    var over:Bool = a.over || b.over;
    return {
      pressed: a.pressed || b.pressed,
      justPressed: a.justPressed || b.justPressed,
      justReleased: a.justReleased || b.justReleased,
      over: over,
      pressedOutside: (a.pressedOutside || b.pressedOutside) && !over
    };
  }

  /** 0..1 fill ratio for the progress bar in hold mode. */
  public static function progress(state:HoldState, seconds:Float):Float
  {
    var total:Float = holdSeconds(seconds);
    if (total <= 0 || state.heldFor <= 0) return 0;
    return Math.min(1, state.heldFor / total);
  }

  /**
   * Advances one guard by a frame.
   *
   * @param state   mutable guard state (see `newState()`)
   * @param input   merged pointer/keyboard input for this frame
   * @param elapsed seconds since the previous frame
   * @param mode    `MODE_HOLD` or `MODE_CONFIRM`
   * @return one of `NONE`, `ARMED`, `CONFIRMED`, `CANCELLED`
   */
  public static function step(state:HoldState, input:HoldInput, elapsed:Float, mode:Int,
      ?seconds:Float = DEFAULT_HOLD_SECONDS, ?window:Float = DEFAULT_CONFIRM_WINDOW):Int
  {
    if (state.done) return NONE;
    if (elapsed == null || elapsed != elapsed || elapsed <= 0) elapsed = 0;
    var limit:Float = holdSeconds(seconds);
    var armedWindow:Float = confirmWindow(window);

    if (mode == MODE_CONFIRM)
    {
      if (state.armed)
      {
        state.armedLeft -= elapsed;
        if (state.armedLeft <= 0 || input.pressedOutside)
        {
          reset(state);
          return CANCELLED;
        }
        // A touch disappears from FlxG.touches on release; `!pressed` on the
        // next frame is what clears the latch for keyboard/gamepad input too.
        if (!input.pressed || input.justReleased) state.needRelease = false;
        if (input.justPressed && input.over && !state.needRelease)
        {
          state.done = true;
          state.armed = false;
          state.active = false;
          return CONFIRMED;
        }
        return NONE;
      }

      if (input.justPressed && input.over)
      {
        state.active = true;
        state.armed = true;
        state.armedLeft = armedWindow;
        state.needRelease = true;
        return ARMED;
      }
      return NONE;
    }

    // MODE_HOLD: the press must stay down and stay on the target.
    if (state.active && (!input.pressed || !input.over))
    {
      reset(state);
      return CANCELLED;
    }
    if (input.justPressed && input.over)
    {
      state.active = true;
      state.heldFor = 0;
    }
    if (state.active && input.pressed && input.over)
    {
      state.heldFor += elapsed;
      if (state.heldFor >= limit)
      {
        state.done = true;
        state.active = false;
        return CONFIRMED;
      }
    }
    return NONE;
  }
}
