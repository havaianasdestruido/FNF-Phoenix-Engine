package objects;

import backend.ClientPrefs;
import backend.HoldToConfirmLogic;
import backend.HoldToConfirmLogic.HoldInput;
import backend.HoldToConfirmLogic.HoldState;
import backend.Paths;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;

/**
 * Guards a destructive UI action behind an intentional gesture.
 *
 * A `HoldToConfirm` is added next to the button/menu row it protects. It owns
 * an invisible enlarged hit area (from {@link TouchTarget}), a small runtime
 * progress bar and a hint line; the protected art is never scaled, recoloured
 * or replaced. Input comes from the mouse, every active touch and an optional
 * `held` callback (keyboard, gamepad or virtual pad), so the same guard works
 * on desktop and mobile.
 *
 * `ClientPrefs.holdToConfirm` chooses between a held press and a second
 * confirmation. Releasing early, dragging off the target, tapping elsewhere,
 * losing focus or running out of time cancels; `onConfirm` fires exactly once.
 *
 * `held` must report whether the key is *down now*, not whether it went down
 * this frame: `backend.Controls` exposes `ACCEPT` / `RESET` bound as
 * `JUST_PRESSED` (true for one frame, so a hold restarts forever) and
 * `ACCEPT_P` / `RESET_P` bound as `PRESSED` (true while held). Use the `_P`
 * variant for every guard.
 *
 * ```haxe
 * var guard = new HoldToConfirm(okButton, doDelete, () -> controls.ACCEPT_P);
 * add(guard);
 * okButton.onUp.callback = null; // the guard owns the press now
 * ```
 */
class HoldToConfirm extends TouchTarget
{
  /** Runs once, after a completed gesture. */
  public var onConfirm:Void->Void = null;
  /**
   * Returns true while the keyboard/gamepad/virtual-pad key for this action is
   * down, so it must read a PRESSED-bound flag (`controls.ACCEPT_P`), never a
   * JUST_PRESSED one (`controls.ACCEPT`). `null` makes the guard pointer-only.
   * Callers fold selection into it, e.g. `() -> onYes && controls.ACCEPT_P`.
   */
  public var held:Void->Bool = null;
  /** Hint shown while holding; the second-confirmation mode overrides it. */
  public var hint:String;
  /** Mutable logic state, exposed for hosts that want to inspect progress. */
  public var state(default, null):HoldState;

  var barBack:FlxSprite;
  var barFill:FlxSprite;
  var label:FlxText;
  var lastHeld:Bool = false;
  /**
   * Brief ignore window after creation/re-targeting. A key or finger still held
   * from the menu that opened this prompt must not count as a fresh press.
   */
  var armDelay:Float = DEFAULT_ARM_DELAY;
  public static inline var DEFAULT_ARM_DELAY:Float = 0.15;

  public function new(?target:FlxObject = null, ?onConfirm:Void->Void = null,
      ?held:Void->Bool = null, ?hint:String = 'HOLD TO CONFIRM')
  {
    super(target, null); // this guard handles presses itself, not TouchTarget.onTap
    this.onConfirm = onConfirm;
    this.held = held;
    this.hint = hint == null ? 'HOLD TO CONFIRM' : hint;
    state = HoldToConfirmLogic.newState();

    barBack = new FlxSprite().makeGraphic(1, 8, FlxColor.BLACK);
    barBack.alpha = 0.7;
    barBack.scrollFactor.set();
    add(barBack);

    barFill = new FlxSprite().makeGraphic(1, 8, 0xFF7CFC00);
    barFill.origin.set(0, 0); // grow from the left edge, not the centre
    barFill.scrollFactor.set();
    add(barFill);

    label = new FlxText(0, 0, 320, this.hint, 16);
    label.setFormat(Paths.font('vcr.ttf'), 16, FlxColor.WHITE, CENTER,
      FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
    label.borderSize = 1.5;
    label.scrollFactor.set();
    label.alignment = CENTER;
    add(label);

    showFeedback(false, 0);
  }

  inline function get_mode():Int
    return ClientPrefs.holdToConfirm ? HoldToConfirmLogic.MODE_HOLD : HoldToConfirmLogic.MODE_CONFIRM;

  inline function get_holdSeconds():Float
    return HoldToConfirmLogic.holdSeconds(ClientPrefs.holdToConfirmTime);

  /**
   * Abandons any pending hold/armed confirmation. Call this when the selection
   * changes, a substate closes, or the guarded button is tapped to cancel.
   */
  public function cancel():Void
  {
    if (state.done) return;
    HoldToConfirmLogic.reset(state);
    lastHeld = false;
    armDelay = DEFAULT_ARM_DELAY;
    showFeedback(false, 0);
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed); // follows the target and skips TouchTarget.onTap
    if (!enabled || onConfirm == null || state.done) return;

    if (armDelay > 0)
    {
      armDelay -= elapsed;
      // Remember a key that was already held, so it is not treated as a new
      // press once the guard starts listening. Don't call cancel() here: it
      // would reset armDelay and keep the guard deaf forever.
      HoldToConfirmLogic.reset(state);
      lastHeld = held != null && held();
      showFeedback(false, 0);
      return;
    }

    var pointer:HoldInput = sample();
    var heldNow:Bool = held != null && held();
    var keyboard:HoldInput = {
      pressed: heldNow,
      justPressed: heldNow && !lastHeld,
      justReleased: !heldNow && lastHeld,
      over: heldNow,
      pressedOutside: false
    };
    lastHeld = heldNow;

    var input:HoldInput = HoldToConfirmLogic.merge(pointer, keyboard);
    var mode:Int = get_mode();
    var result:Int = HoldToConfirmLogic.step(state, input, elapsed, mode,
      get_holdSeconds(), HoldToConfirmLogic.DEFAULT_CONFIRM_WINDOW);

    if (result == HoldToConfirmLogic.CONFIRMED)
    {
      showFeedback(false, 0);
      enabled = false; // one-shot even if the host keeps this object alive
      FlxG.sound.play(Paths.sound('confirmMenu'), 0.6);
      if (onConfirm != null) onConfirm();
      return;
    }
    if (result == HoldToConfirmLogic.CANCELLED)
    {
      showFeedback(false, 0);
      return;
    }
    if (result == HoldToConfirmLogic.ARMED)
      FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

    var ratio:Float = 0;
    if (mode == HoldToConfirmLogic.MODE_HOLD)
      ratio = HoldToConfirmLogic.progress(state, get_holdSeconds());
    else if (state.armed)
      ratio = Math.max(0, state.armedLeft / HoldToConfirmLogic.confirmWindow());
    showFeedback(state.active || state.armed, ratio);
  }

  /** Positions the bar/hint over the enlarged bounds and updates their size. */
  function showFeedback(visible:Bool, ratio:Float):Void
  {
    barBack.visible = barFill.visible = label.visible = visible;
    if (!visible) return;

    var x:Float = bounds.x;
    var y:Float = bounds.y + bounds.height + 4;
    var width:Float = Math.max(120, bounds.width);
    if (target == null)
    {
      x = FlxG.width * 0.5 - width * 0.5;
      y = FlxG.height - 90;
    }

    barBack.setPosition(x, y);
    barBack.scale.x = width;
    barFill.setPosition(x, y);
    barFill.scale.x = Math.max(0.001, width * Math.min(1, Math.max(0, ratio)));

    label.fieldWidth = width;
    label.setPosition(x, Math.max(0, y - 26));
    var text:String = get_mode() == HoldToConfirmLogic.MODE_HOLD ? hint : 'TAP AGAIN TO CONFIRM';
    if (label.text != text) label.text = text;
  }

  override public function destroy():Void
  {
    onConfirm = null;
    held = null;
    super.destroy();
  }
}
