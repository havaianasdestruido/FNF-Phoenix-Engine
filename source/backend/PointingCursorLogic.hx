package backend;

/**
 * Renderer-free pick/anchor rules for the pointing-finger menu cursor, ported
 * from the HaxeFlixel Cursor demo (`FlxUICursor` in flixel-ui, MIT).
 *
 * The demo parks a finger sprite on the focused widget: keyboard and gamepad
 * move that focus, and moving the mouse over a widget jumps the finger there.
 * Phoenix applies the same math to regular menu sprites instead of
 * `IFlxUIWidget`.
 *
 * Kept free of Flixel/OpenFL/Lime so `tests/haxe/PointingCursorSpec.hx` can
 * run under `haxe --interp` without the game haxelibs.
 */
class PointingCursorLogic
{
  /** Default style preset name (the demo's pointing finger). */
  public static inline var DEFAULT_STYLE:String = 'Finger';

  /** Default tint preset name. */
  public static inline var DEFAULT_COLOR:String = 'White';

  /**
   * Horizontal offset matching `FlxUICursor`'s default
   * `Anchor(-2, 0, LEFT, CENTER, RIGHT, CENTER)`.
   */
  public static inline var ANCHOR_OFFSET_X:Float = -2;

  /**
   * Vertical offset matching `FlxUICursor`'s default
   * `Anchor(-2, 0, LEFT, CENTER, RIGHT, CENTER)`.
   */
  public static inline var ANCHOR_OFFSET_Y:Float = 0;

  static final STYLE_ORDER:Array<String> = ['Finger', 'Arrow', 'Triangle'];

  static final COLOR_ORDER:Array<String> = ['White', 'Pink', 'Cyan', 'Yellow', 'Green', 'Black'];

  static final COLOR_MAP:Map<String, Int> = [
    'white' => 0xFFFFFFFF,
    'pink' => 0xFFFF16D2,
    'cyan' => 0xFF00E5FF,
    'yellow' => 0xFFFFD800,
    'green' => 0xFF2ECC71,
    'black' => 0xFF1A1A1A
  ];

  /**
   * Ordered style preset names for Options menus.
   *
   * @return a fresh copy of the style list
   */
  public static function styleNames():Array<String>
    return STYLE_ORDER.copy();

  /**
   * Ordered color preset names for Options menus.
   *
   * @return a fresh copy of the color list
   */
  public static function colorNames():Array<String>
    return COLOR_ORDER.copy();

  /**
   * Normalizes a saved or user-supplied style name.
   *
   * @param name raw style name
   * @return canonical name from `styleNames()`, or `DEFAULT_STYLE`
   */
  public static function normalizeStyle(name:String):String
  {
    return normalizeFrom(name, STYLE_ORDER, DEFAULT_STYLE);
  }

  /**
   * Normalizes a saved or user-supplied color preset name.
   *
   * @param name raw color name
   * @return canonical name from `colorNames()`, or `DEFAULT_COLOR`
   */
  public static function normalizeColor(name:String):String
  {
    return normalizeFrom(name, COLOR_ORDER, DEFAULT_COLOR);
  }

  /**
   * Resolves a color preset name to an ARGB integer.
   *
   * @param name preset name (case-insensitive)
   * @return `0xAARRGGBB` tint
   */
  public static function colorValue(name:String):Int
  {
    final canonical:String = normalizeColor(name).toLowerCase();
    final value:Null<Int> = COLOR_MAP.get(canonical);
    return value != null ? value : 0xFFFFFFFF;
  }

  /**
   * Pixel size of the cursor graphic for a style preset.
   *
   * @param style style name (case-insensitive)
   * @return width and height in pixels
   */
  public static function spriteSize(style:String):{width:Int, height:Int}
  {
    return switch (normalizeStyle(style))
    {
      case 'Arrow': {width: 24, height: 24};
      case 'Triangle': {width: 20, height: 20};
      default: {width: 32, height: 32};
    };
  }

  /**
   * On-screen hit rectangle of a menu member, in the coordinate space of the
   * camera that draws it.
   *
   * A member is not drawn at its world position once its camera has scrolled
   * or its scroll factor differs from 1: it appears at
   * `position - cameraScroll * scrollFactor`. Hover picking has to test the
   * pointer against that rectangle — the one the player actually sees — which
   * is also the space `FlxG.mouse.getScreenPosition(camera)` reports the
   * pointer in. Testing the world rectangle against the world pointer instead
   * drifts by `cameraScroll * (1 - scrollFactor)` on scrolling menus (the
   * Phoenix main menu pans its camera and gives items a 0.405 scroll factor),
   * which made the finger snap to items the pointer was not on and fight
   * keyboard scrolling.
   *
   * @param x member world left
   * @param y member world top
   * @param width member hitbox width
   * @param height member hitbox height
   * @param scrollX camera horizontal scroll
   * @param scrollY camera vertical scroll
   * @param scrollFactorX member horizontal scroll factor
   * @param scrollFactorY member vertical scroll factor
   * @param visible whether the member is currently drawable
   * @return the member's on-screen rectangle, for `pickByPointer`
   */
  public static function screenRect(x:Float, y:Float, width:Float, height:Float, scrollX:Float, scrollY:Float,
      scrollFactorX:Float, scrollFactorY:Float, visible:Bool):PointingTarget
  {
    return {
      x: x - scrollX * scrollFactorX,
      y: y - scrollY * scrollFactorY,
      width: width,
      height: height,
      visible: visible
    };
  }

  /**
   * Whether a target can receive the pointing sprite.
   *
   * @param target candidate rectangle
   * @return true when it is visible and has a positive size
   */
  public static function isPointable(target:PointingTarget):Bool
  {
    if (target == null || !target.visible) return false;
    if (target.width != target.width || target.height != target.height) return false;
    return target.width > 0 && target.height > 0;
  }

  /**
   * Index of the visible target whose bounds contain `(px, py)`.
   * Overlapping targets prefer the closest center, matching
   * `FlxUICursor.jumpToXY`.
   *
   * @param targets pointable rectangles
   * @param px pointer x in the same space as `target.x`
   * @param py pointer y in the same space as `target.y`
   * @return index into `targets`, or `-1` when nothing is under the pointer
   */
  public static function pickByPointer(targets:Array<PointingTarget>, px:Float, py:Float):Int
  {
    if (targets == null || px != px || py != py) return -1;

    var bestIndex:Int = -1;
    var bestDist2:Float = Math.POSITIVE_INFINITY;
    for (i in 0...targets.length)
    {
      final target:PointingTarget = targets[i];
      if (!isPointable(target)) continue;
      if (px < target.x || py < target.y) continue;
      if (px > target.x + target.width || py > target.y + target.height) continue;

      final dx:Float = (target.x + target.width * 0.5) - px;
      final dy:Float = (target.y + target.height * 0.5) - py;
      final dist2:Float = dx * dx + dy * dy;
      if (dist2 < bestDist2)
      {
        bestDist2 = dist2;
        bestIndex = i;
      }
    }
    return bestIndex;
  }

  /**
   * First visible target at or after `index`. Walks forward (and wraps when
   * asked) the way `FlxUICursor.findVisibleLocation` skips hidden widgets.
   *
   * @param targets pointable rectangles
   * @param index requested index
   * @param wrap wrap around when walking past the end
   * @return visible index, or `-1` when none are pointable
   */
  public static function visibleIndex(targets:Array<PointingTarget>, index:Int, wrap:Bool = true):Int
  {
    if (targets == null || targets.length == 0) return -1;

    var start:Int = index;
    if (start != start) start = 0;
    if (start < 0) start = 0;
    if (start >= targets.length) start = targets.length - 1;

    var cursor:Int = start;
    for (_ in 0...targets.length)
    {
      if (isPointable(targets[cursor])) return cursor;
      cursor++;
      if (cursor >= targets.length)
      {
        if (!wrap) return -1;
        cursor = 0;
      }
    }
    return -1;
  }

  /**
   * Top-left of a sprite whose right-center sits on the target's left-center.
   * Matches `FlxUICursor`'s default anchor (widget `LEFT/CENTER`, cursor
   * `RIGHT/CENTER`) so the finger points at the button from the left.
   *
   * @param targetX target left
   * @param targetY target top
   * @param targetW target width
   * @param targetH target height
   * @param spriteW cursor sprite width
   * @param spriteH cursor sprite height
   * @param offsetX extra x after flushing (default `ANCHOR_OFFSET_X`)
   * @param offsetY extra y after flushing (default `ANCHOR_OFFSET_Y`)
   * @return top-left coordinates for the cursor sprite
   */
  public static function anchorPosition(targetX:Float, targetY:Float, targetW:Float, targetH:Float,
      spriteW:Float, spriteH:Float, ?offsetX:Float, ?offsetY:Float):{x:Float, y:Float}
  {
    final offX:Float = offsetX == null ? ANCHOR_OFFSET_X : offsetX;
    final offY:Float = offsetY == null ? ANCHOR_OFFSET_Y : offsetY;
    final safeSpriteW:Float = (spriteW != spriteW || spriteW < 0) ? 0 : spriteW;
    final safeSpriteH:Float = (spriteH != spriteH || spriteH < 0) ? 0 : spriteH;
    final safeTargetH:Float = (targetH != targetH) ? 0 : targetH;
    return {
      x: targetX - safeSpriteW + offX,
      y: targetY + safeTargetH * 0.5 - safeSpriteH * 0.5 + offY
    };
  }

  /**
   * Whether the overlay should draw.
   *
   * @param enabled ClientPrefs toggle
   * @param hasTarget a visible widget is selected
   * @return true when the finger should be shown
   */
  public static function shouldShow(enabled:Bool, hasTarget:Bool):Bool
  {
    return enabled && hasTarget;
  }

  /**
   * Resolves `name` against an ordered preset list, ignoring case and trim.
   *
   * @param name raw value
   * @param order canonical names
   * @param fallback value used when `name` is missing or unknown
   * @return canonical name from `order`, or `fallback`
   */
  static function normalizeFrom(name:String, order:Array<String>, fallback:String):String
  {
    if (name == null) return fallback;
    final trimmed:String = StringTools.trim(name).toLowerCase();
    if (trimmed.length == 0) return fallback;
    for (preset in order)
      if (preset.toLowerCase() == trimmed) return preset;
    return fallback;
  }
}

/**
 * Axis-aligned rectangle the pointing cursor can attach to.
 */
typedef PointingTarget =
{
  var x:Float;
  var y:Float;
  var width:Float;
  var height:Float;
  var visible:Bool;
}
