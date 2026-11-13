package objects;

import backend.HoldToConfirmLogic;
import backend.HoldToConfirmLogic.HoldInput;
import backend.HoldToConfirmLogic.TouchRect;
import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup;
import flixel.input.FlxPointer;
import flixel.util.FlxColor;

/**
 * An invisible, enlarged tap area laid over existing art.
 *
 * Menus authored at 1280x720 often leave 20-40 px tall text as the only thing
 * a finger can hit. This class keeps the original sprite untouched and adds a
 * transparent `FlxSprite` of at least {@link HoldToConfirmLogic#MIN_TOUCH_SIZE}
 * units on both axes, centred on the visual bounds. The hit area follows the
 * target every frame, so animated menu items (Alphabet lerp, resize shifts)
 * stay covered without re-laying out any art.
 *
 * `sample()` reports pointer input (mouse plus every active touch) in the
 * renderer-free `HoldInput` shape, and `onTap` handles plain, non-destructive
 * buttons. Destructive buttons use `objects.HoldToConfirm` instead.
 */
class TouchTarget extends FlxSpriteGroup
{
  /** Visual object whose art must stay unchanged. May be swapped at runtime. */
  public var target:FlxObject = null;
  /** The transparent sprite that actually receives pointer checks. */
  public var hitSprite(default, null):FlxSprite;
  /** Fired on a single press when this is not a guarded action. */
  public var onTap:Void->Void = null;
  /** Set false to temporarily ignore input (e.g. while a text field has focus). */
  public var enabled:Bool = true;
  /** Set false for keyboard/gamepad-only guards with no on-screen target. */
  public var allowPointer:Bool = true;

  public var minWidth:Float = HoldToConfirmLogic.MIN_TOUCH_SIZE;
  public var minHeight:Float = HoldToConfirmLogic.MIN_TOUCH_SIZE;
  public var padding:Float = HoldToConfirmLogic.TOUCH_PADDING;

  /** Last computed bounds, in world units. Kept public for progress overlays. */
  public var bounds(default, null):TouchRect = {x: 0, y: 0, width: 0, height: 0};

  public function new(?target:FlxObject = null, ?onTap:Void->Void = null)
  {
    super(0, 0);
    this.target = target;
    this.onTap = onTap;

    hitSprite = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
    hitSprite.alpha = 0; // invisible, but still a valid bounding box for overlaps
    add(hitSprite);

    if (target != null && target.cameras != null)
      cameras = target.cameras;
    fitToTarget();
  }

  /** Recomputes the enlarged rectangle and moves/resizes only the hit sprite. */
  public function fitToTarget():Void
  {
    if (target == null)
    {
      hitSprite.visible = false;
      return;
    }

    bounds = HoldToConfirmLogic.grow(target.x, target.y, target.width, target.height,
      minWidth, minHeight, padding);
    hitSprite.visible = true;
    hitSprite.setPosition(bounds.x, bounds.y);
    hitSprite.scale.set(bounds.width, bounds.height);
    hitSprite.updateHitbox();
    hitSprite.scrollFactor.set(target.scrollFactor.x, target.scrollFactor.y);
  }

  /** Whether a pointer's world position is inside the enlarged area. */
  function overlapsPointer(pointer:FlxPointer):Bool
  {
    if (pointer == null || !hitSprite.visible) return false;
    for (camera in cameras)
      if (pointer.overlaps(hitSprite, camera)) return true;
    return false;
  }

  /**
   * Reads one frame of pointer input. Touches that were released this frame
   * are still in `FlxG.touches.list`, so a drag out of the target cancels a
   * hold instead of silently completing it.
   */
  public function sample():HoldInput
  {
    if (!enabled || !allowPointer || target == null || !hitSprite.visible)
      return HoldToConfirmLogic.idle();

    var over:Bool = false;
    var pressed:Bool = false;
    var justPressed:Bool = false;
    var justReleased:Bool = false;
    var outside:Bool = false;

    #if !FLX_NO_MOUSE
    if (FlxG.mouse != null)
    {
      var mouse = FlxG.mouse;
      var inside:Bool = overlapsPointer(mouse);
      over = over || inside;
      pressed = pressed || (inside && mouse.pressed);
      justPressed = justPressed || (inside && mouse.justPressed);
      justReleased = justReleased || mouse.justReleased;
      if (mouse.justPressed && !inside) outside = true;
    }
    #end

    #if FLX_TOUCH
    if (FlxG.touches != null)
    {
      for (touch in FlxG.touches.list)
      {
        if (touch == null) continue;
        var inside:Bool = overlapsPointer(touch);
        over = over || inside;
        pressed = pressed || (inside && touch.pressed);
        justPressed = justPressed || (inside && touch.justPressed);
        justReleased = justReleased || touch.justReleased;
        if (touch.justPressed && !inside) outside = true;
      }
    }
    #end

    return {
      pressed: pressed,
      justPressed: justPressed,
      justReleased: justReleased,
      over: over,
      pressedOutside: outside && !over
    };
  }

  override public function update(elapsed:Float):Void
  {
    super.update(elapsed);
    fitToTarget();
    if (enabled && onTap != null)
    {
      var input:HoldInput = sample();
      if (input.justPressed && input.over) onTap();
    }
  }

  /**
   * Menus select a row by tapping it. This uses the *padded* rectangle, not the
   * small art bounds, and the same camera list as the target so rows drawn on a
   * secondary camera still work. `paddedHit` is a scratch sprite: it is never
   * added to a state and never drawn.
   */
  static var paddedHit:FlxSprite = null;

  public static function justPressedOver(object:FlxObject, ?cams:Array<FlxCamera>):Bool
  {
    if (object == null) return false;
    if (paddedHit == null)
    {
      paddedHit = new FlxSprite().makeGraphic(1, 1, FlxColor.TRANSPARENT);
      paddedHit.alpha = 0;
    }

    var rect:TouchRect = HoldToConfirmLogic.grow(object.x, object.y,
      object.width, object.height, HoldToConfirmLogic.MIN_TOUCH_SIZE,
      HoldToConfirmLogic.MIN_TOUCH_SIZE, HoldToConfirmLogic.TOUCH_PADDING);
    paddedHit.setPosition(rect.x, rect.y);
    paddedHit.scale.set(rect.width, rect.height);
    paddedHit.updateHitbox();
    paddedHit.scrollFactor.set(object.scrollFactor.x, object.scrollFactor.y);
    paddedHit.visible = true;

    var list:Array<FlxCamera> = (cams != null && cams.length > 0) ? cams : FlxG.cameras.list;

    #if !FLX_NO_MOUSE
    if (FlxG.mouse != null && FlxG.mouse.justPressed)
      for (camera in list)
        if (FlxG.mouse.overlaps(paddedHit, camera)) return true;
    #end

    #if FLX_TOUCH
    if (FlxG.touches != null)
      for (touch in FlxG.touches.list)
      {
        if (touch == null || !touch.justPressed) continue;
        for (camera in list)
          if (touch.overlaps(paddedHit, camera)) return true;
      }
    #end

    return false;
  }

  override public function destroy():Void
  {
    onTap = null;
    target = null;
    super.destroy();
  }
}
