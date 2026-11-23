import backend.PointingCursorLogic;
import backend.PointingCursorLogic.PointingTarget;

/**
 * Contract for the pointing-finger menu cursor ported from the HaxeFlixel
 * Cursor demo: style/color presets, jumpToXY picking, visible-slot walking,
 * the left-center anchor used by `FlxUICursor`, and the camera-space
 * rectangles hover picking tests the pointer against on scrolling menus.
 */
class PointingCursorSpec
{
  static var failures:Int = 0;

  static function check(ok:Bool, label:String, ?pos:haxe.PosInfos):Void
  {
    if (ok) return;
    failures++;
    trace('FAIL: ' + label + ' @' + (pos == null ? 0 : pos.lineNumber));
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    check(Math.abs(actual - expected) < 0.0001, '$label (expected $expected, got $actual)');
  }

  static function box(x:Float, y:Float, w:Float, h:Float, visible:Bool = true):PointingTarget
  {
    return {x: x, y: y, width: w, height: h, visible: visible};
  }

  static function main():Void
  {
    testPresets();
    testPointable();
    testScreenRect();
    testPickByPointer();
    testScrolledMenuHover();
    testVisibleIndex();
    testAnchor();
    testShouldShow();

    if (failures > 0)
      throw 'PointingCursorSpec: $failures failure(s)';
    trace('PointingCursorSpec: PASS');
  }

  static function testPresets():Void
  {
    final styles:Array<String> = PointingCursorLogic.styleNames();
    check(styles.length >= 2, 'at least two style presets exist');
    check(styles[0] == PointingCursorLogic.DEFAULT_STYLE, 'Finger leads the style list');
    check(styles.indexOf('Arrow') >= 0, 'Arrow style is offered');
    check(styles.indexOf('Triangle') >= 0, 'Triangle style is offered');

    check(PointingCursorLogic.normalizeStyle(null) == PointingCursorLogic.DEFAULT_STYLE, 'null style falls back');
    check(PointingCursorLogic.normalizeStyle('  ') == PointingCursorLogic.DEFAULT_STYLE, 'blank style falls back');
    check(PointingCursorLogic.normalizeStyle('  aRrOw ') == 'Arrow', 'style normalization trims and ignores case');
    check(PointingCursorLogic.normalizeStyle('nope') == PointingCursorLogic.DEFAULT_STYLE, 'unknown style falls back');

    final colors:Array<String> = PointingCursorLogic.colorNames();
    check(colors[0] == PointingCursorLogic.DEFAULT_COLOR, 'White leads the color list');
    check(PointingCursorLogic.normalizeColor(null) == PointingCursorLogic.DEFAULT_COLOR, 'null color falls back');
    check(PointingCursorLogic.normalizeColor('  pInK ') == 'Pink', 'color normalization trims and ignores case');
    check(PointingCursorLogic.colorValue('White') == 0xFFFFFFFF, 'white tint is opaque white');
    check(PointingCursorLogic.colorValue('pink') == 0xFFFF16D2, 'pink tint matches Phoenix accent');
    check(PointingCursorLogic.colorValue('garbage') == 0xFFFFFFFF, 'invalid color falls back to white');

    final finger = PointingCursorLogic.spriteSize('Finger');
    check(finger.width == 32 && finger.height == 32, 'Finger style is 32x32 like FlxUICursor IMG_FINGER_BIG');
    final arrow = PointingCursorLogic.spriteSize('arrow');
    check(arrow.width == 24 && arrow.height == 24, 'Arrow style is 24x24');
    final tri = PointingCursorLogic.spriteSize('Triangle');
    check(tri.width == 20 && tri.height == 20, 'Triangle style is 20x20');
  }

  static function testPointable():Void
  {
    check(!PointingCursorLogic.isPointable(null), 'null is not pointable');
    check(!PointingCursorLogic.isPointable(box(0, 0, 10, 10, false)), 'hidden target is not pointable');
    check(!PointingCursorLogic.isPointable(box(0, 0, 0, 10)), 'zero width is not pointable');
    check(!PointingCursorLogic.isPointable(box(0, 0, 10, 0)), 'zero height is not pointable');
    check(PointingCursorLogic.isPointable(box(0, 0, 10, 10)), 'visible positive rect is pointable');
  }

  static function testScreenRect():Void
  {
    // Scroll factor 1 (freeplay, story and pause rows): the on-screen rect
    // follows the camera by the whole scroll.
    final full:PointingTarget = PointingCursorLogic.screenRect(100, 200, 50, 60, 40, 80, 1, 1, true);
    near(full.x, 60, 'factor 1 subtracts the full horizontal scroll');
    near(full.y, 120, 'factor 1 subtracts the full vertical scroll');
    near(full.width, 50, 'width passes through');
    near(full.height, 60, 'height passes through');
    check(full.visible, 'visibility passes through');

    // Scroll factor 0 (HUD-pinned rows): the rect ignores the camera.
    final pinned:PointingTarget = PointingCursorLogic.screenRect(100, 200, 50, 60, 40, 80, 0, 0, true);
    near(pinned.x, 100, 'factor 0 keeps the world x');
    near(pinned.y, 200, 'factor 0 keeps the world y');

    // Parallax rows (the main menu items scroll at 0.405 with seven options):
    // the rect shifts by only the scroll-factor share of the camera movement.
    final parallax:PointingTarget = PointingCursorLogic.screenRect(100, 200, 50, 60, 0, 100, 0, 0.405, true);
    near(parallax.x, 100, 'horizontal factor 0 keeps the world x');
    near(parallax.y, 200 - 40.5, 'partial factor shifts by scroll * factor');

    // No camera scroll: the on-screen rect equals the world rect whatever the
    // factors, so static menus pick exactly what they always did.
    final still:PointingTarget = PointingCursorLogic.screenRect(332.5, -132, 615, 122, 0, 0, 0.405, 0.405, true);
    near(still.x, 332.5, 'no scroll keeps x');
    near(still.y, -132, 'no scroll keeps y');
  }

  static function testPickByPointer():Void
  {
    final targets:Array<PointingTarget> = [
      box(0, 0, 40, 20),
      box(0, 30, 40, 20),
      box(0, 60, 40, 20, false)
    ];

    check(PointingCursorLogic.pickByPointer(null, 10, 10) == -1, 'null list yields -1');
    check(PointingCursorLogic.pickByPointer(targets, Math.NaN, 10) == -1, 'NaN pointer yields -1');
    check(PointingCursorLogic.pickByPointer(targets, 10, 10) == 0, 'pointer inside first button');
    check(PointingCursorLogic.pickByPointer(targets, 10, 40) == 1, 'pointer inside second button');
    check(PointingCursorLogic.pickByPointer(targets, 10, 70) == -1, 'hidden button is ignored even if overlapped');
    check(PointingCursorLogic.pickByPointer(targets, 100, 10) == -1, 'pointer outside every button');

    // Overlapping widgets: closest center wins, matching FlxUICursor.jumpToXY.
    final overlap:Array<PointingTarget> = [
      box(0, 0, 100, 40),
      box(60, 0, 40, 40)
    ];
    check(PointingCursorLogic.pickByPointer(overlap, 70, 20) == 1, 'overlap prefers the closer center');
    check(PointingCursorLogic.pickByPointer(overlap, 20, 20) == 0, 'left side of the overlap stays on the large button');
  }

  /**
   * The reported main-menu bug: with seven options the items scroll at 0.405
   * while the camera centers on the selection, so testing the world rectangle
   * against the world pointer (what `FlxG.mouse.x/y` report) drifts by
   * `scroll * (1 - 0.405)`. Layout constants are the real ones: 615x122 items
   * spaced 140px apart from world y = -132, camera `scroll.y = 140 * selection
   * - 487` on a 1280x720 game. The pointer rests at (640, 110) and never
   * moves; only the camera pans as the player scrolls.
   */
  static function testScrolledMenuHover():Void
  {
    final worldRects:Array<PointingTarget> = [for (i in 0...7) box(332.5, -132 + 140 * i, 615, 122)];

    function screenRectsAt(selection:Int):Array<PointingTarget>
    {
      final scroll:Float = 140 * selection - 487;
      return [
        for (i in 0...7)
          PointingCursorLogic.screenRect(332.5, -132 + 140 * i, 615, 122, 0, scroll, 0, 0.405, true)
      ];
    }

    // Selection 6 (options): mods is the row actually drawn at the pointer.
    check(PointingCursorLogic.pickByPointer(screenRectsAt(6), 640, 110) == 2,
      'scrolled camera picks the row drawn under the pointer');

    // The world-space test the cursor used to run lands on credits instead:
    // pressing DOWN onto options snapped the selection back UP two slots.
    final worldPointerY:Float = 110 + (140 * 6 - 487);
    check(PointingCursorLogic.pickByPointer(worldRects, 640, worldPointerY) == 4,
      'world-space pick (the old bug) points two slots above the selection');

    // Selection 2 (mods): the second press down snapped straight back to the
    // top item, so the list never let the player past it ("making me stuck").
    final earlyWorldPointerY:Float = 110 + (140 * 2 - 487);
    check(PointingCursorLogic.pickByPointer(worldRects, 640, earlyWorldPointerY) == 0,
      'world-space pick at the second item already answers the top item');
    check(PointingCursorLogic.pickByPointer(screenRectsAt(2), 640, 110) == 1,
      'camera-space pick at the second item answers the row drawn under the pointer');

    // Selection 4 (credits): the pointer sits in the on-screen gap between
    // rows, so nothing is hovered — while the world-space test claims the row
    // two slots below the gap.
    check(PointingCursorLogic.pickByPointer(screenRectsAt(4), 640, 110) == -1,
      'pointer in the on-screen gap between rows hovers nothing');
    check(PointingCursorLogic.pickByPointer(worldRects, 640, 110 + (140 * 4 - 487)) == 2,
      'world-space pick hovers a row the pointer is not on');
  }

  static function testVisibleIndex():Void
  {
    final targets:Array<PointingTarget> = [
      box(0, 0, 10, 10, false),
      box(0, 20, 10, 10),
      box(0, 40, 10, 10, false),
      box(0, 60, 10, 10)
    ];

    check(PointingCursorLogic.visibleIndex(null, 0) == -1, 'null list has no visible index');
    check(PointingCursorLogic.visibleIndex([], 0) == -1, 'empty list has no visible index');
    check(PointingCursorLogic.visibleIndex(targets, 0) == 1, 'hidden slot 0 walks forward to 1');
    check(PointingCursorLogic.visibleIndex(targets, 1) == 1, 'already-visible slot stays');
    check(PointingCursorLogic.visibleIndex(targets, 2) == 3, 'hidden slot 2 walks forward to 3');
    check(PointingCursorLogic.visibleIndex(targets, 3) == 3, 'last visible slot stays');
    check(PointingCursorLogic.visibleIndex(targets, 99) == 3, 'overflow clamps then walks to a visible slot');
    check(PointingCursorLogic.visibleIndex(targets, -4) == 1, 'negative index clamps to 0 then walks forward');

    final allHidden:Array<PointingTarget> = [box(0, 0, 10, 10, false), box(0, 20, 10, 10, false)];
    check(PointingCursorLogic.visibleIndex(allHidden, 0, true) == -1, 'wrap still fails when every slot is hidden');
    check(PointingCursorLogic.visibleIndex(targets, 3, false) == 3, 'no-wrap keeps a visible last slot');
    check(PointingCursorLogic.visibleIndex([box(0, 0, 10, 10, false)], 0, false) == -1,
      'no-wrap returns -1 when the only slot is hidden');
  }

  static function testAnchor():Void
  {
    // Right-center of a 32x32 finger on the left-center of a 200x40 button at (100, 80):
    // x = 100 - 32 + (-2) = 66
    // y = 80 + 20 - 16 + 0 = 84
    final pos = PointingCursorLogic.anchorPosition(100, 80, 200, 40, 32, 32);
    near(pos.x, 66, 'default anchor sits 2px left of the button');
    near(pos.y, 84, 'default anchor vertically centers on the button');

    final custom = PointingCursorLogic.anchorPosition(0, 0, 10, 10, 8, 8, 0, 0);
    near(custom.x, -8, 'zero offset puts the sprite flush against the left edge');
    near(custom.y, 1, 'zero offset vertically centers an 8px sprite on a 10px target');

    final nanH = PointingCursorLogic.anchorPosition(10, 10, 10, Math.NaN, 8, 8, 0, 0);
    near(nanH.y, 10 - 4, 'NaN target height is treated as 0');
  }

  static function testShouldShow():Void
  {
    check(PointingCursorLogic.shouldShow(true, true), 'enabled with a target shows the finger');
    check(!PointingCursorLogic.shouldShow(false, true), 'disabled pref hides the finger');
    check(!PointingCursorLogic.shouldShow(true, false), 'no target hides the finger');
    check(!PointingCursorLogic.shouldShow(false, false), 'disabled and empty stays hidden');
  }
}
