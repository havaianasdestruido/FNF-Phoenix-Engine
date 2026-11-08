import backend.MenuLayout;

/**
 * Contract tests for `backend.MenuLayout`.
 *
 * The module is Flixel-free on purpose, so the rules that center a settings list
 * can be checked in the Haxe interpreter, without the game's haxelibs.
 *
 *     bash tests/haxe/run-menu-layout.sh
 */
class MenuLayoutSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal(actual:Float, expected:Float, label:String):Void
  {
    if (Math.abs(actual - expected) > 0.0001)
      throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    measuresRows();
    blockWidths();
    centersBlocks();
    placesColumns();
    cancelsCheckboxAnchor();
    keepsLongRowsOnScreen();
  }

  /** A row is the sum of its parts plus one gap between each pair. */
  static function measuresRows():Void
  {
    equal(MenuLayout.rowWidth(400, 0, 0, false, false), 400, 'label only');
    equal(MenuLayout.rowWidth(400, 0, 60, false, true), 400 + 60 + MenuLayout.PART_GAP, 'checkbox and label');
    equal(MenuLayout.rowWidth(400, 120, 0, true, false), 400 + 120 + MenuLayout.PART_GAP, 'label and value');
    equal(MenuLayout.rowWidth(400, 120, 60, true, true), 400 + 120 + 60 + MenuLayout.PART_GAP * 2, 'all three parts');

    // A negative width cannot make a row wider than its parts are.
    equal(MenuLayout.rowWidth(400, -30, -10, true, true), 400 + 2 * MenuLayout.PART_GAP, 'negative parts are ignored');

    // An empty label still leaves the gap between the remaining parts.
    equal(MenuLayout.rowWidth(0, 100, 50, true, true), 150 + 2 * MenuLayout.PART_GAP, 'empty label');
    equal(MenuLayout.rowWidth(0, 0, 0, false, false), 0, 'empty row');
  }

  /** The block width is the widest row, however the columns line up. */
  static function blockWidths():Void
  {
    equal(MenuLayout.blockWidth(400, 0, 0, false), 400, 'labels only');
    equal(MenuLayout.blockWidth(400, 0, 64, true), 400 + 64 + MenuLayout.PART_GAP, 'checkbox column');
    equal(MenuLayout.blockWidth(400, 120, 0, false), 400 + 120 + MenuLayout.PART_GAP, 'value column');
    equal(MenuLayout.blockWidth(400, 120, 64, true), 400 + 120 + 64 + MenuLayout.PART_GAP * 2, 'three columns');
  }

  /** Centering is symmetric and never leaves the content area. */
  static function centersBlocks():Void
  {
    equal(MenuLayout.centeredStart(400, 1280, 0), 440, 'centered on 1280');
    equal(MenuLayout.centeredStart(400, 1720, 220), 660, 'centered on widescreen');

    // The block center is the viewport center: that is the whole point.
    final width:Float = 613;
    final left:Float = MenuLayout.centeredStart(width, 1720, 220);
    equal(left + width / 2, 1720 / 2, 'block center on the viewport center');

    // A block wider than the screen starts at the content origin instead of
    // hanging off the left edge where it could not be read.
    equal(MenuLayout.centeredStart(2000, 1280, 0), 0, 'overflow on 16:9');
    equal(MenuLayout.centeredStart(2000, 1720, 220), 220, 'overflow on widescreen');
    equal(MenuLayout.centeredStart(0, 1280, 0), 640, 'empty block sits at the center');
    equal(MenuLayout.centeredStart(-10, 1280, 0), 640, 'negative width is treated as empty');
  }

  /** The three columns are placed one after another, separated by one gap. */
  static function placesColumns():Void
  {
    final blockLeft:Float = 300;

    // No checkbox: the labels start at the block's left edge.
    equal(MenuLayout.labelColumn(blockLeft, 64, false), blockLeft, 'labels without checkboxes');

    // With a checkbox column, labels start after the widest box.
    equal(MenuLayout.labelColumn(blockLeft, 64, true), blockLeft + 64 + MenuLayout.PART_GAP, 'labels after checkbox column');

    // Values always start right of the widest label.
    equal(MenuLayout.valueColumn(blockLeft, 400), blockLeft + 400 + MenuLayout.PART_GAP, 'values after labels');
    equal(MenuLayout.valueColumn(blockLeft + 100, 400), blockLeft + 100 + 400 + MenuLayout.PART_GAP, 'values follow the label column');

    // Measure and placement agree: the widest row ends where centering says.
    final labelWidth:Float = 420;
    final valueWidth:Float = 96;
    final boxWidth:Float = 64;
    final rowWidth:Float = MenuLayout.rowWidth(labelWidth, valueWidth, boxWidth, true, true);
    final left:Float = MenuLayout.centeredStart(rowWidth, 1280, 0);
    final labels:Float = MenuLayout.labelColumn(left, boxWidth, true);
    final values:Float = MenuLayout.valueColumn(labels, labelWidth);
    equal(left, 1280 / 2 - rowWidth / 2, 'centered row starts where expected');
    equal(values + valueWidth, left + rowWidth, 'the value ends the centered row');
  }

  /** A checkbox offset cancels `CheckboxThingie`'s own tracker anchor. */
  static function cancelsCheckboxAnchor():Void
  {
    final labelLeft:Float = 500;
    final boxWidth:Float = 58;

    // CheckboxThingie draws itself at `sprTracker.x + CHECKBOX_TRACK_OFFSET +
    // offsetX`; with the layout's offset it lands one gap left of the labels.
    final drawn:Float = labelLeft + MenuLayout.CHECKBOX_TRACK_OFFSET + MenuLayout.checkboxOffset(labelLeft, boxWidth);
    equal(drawn, labelLeft - MenuLayout.PART_GAP - boxWidth, 'checkbox ends one gap before the labels');

    // The sprite's anchor is part of the contract: if objects.CheckboxThingie
    // ever changes it, this test is the reminder that the layout has to follow.
    equal(MenuLayout.CHECKBOX_TRACK_OFFSET, -130, 'CheckboxThingie tracker anchor');

    // The offset does not depend on where the labels start.
    equal(MenuLayout.checkboxOffset(0, 10), MenuLayout.checkboxOffset(labelLeft, 10), 'origin independent');
    equal(MenuLayout.checkboxOffset(0, 0), -MenuLayout.PART_GAP - MenuLayout.CHECKBOX_TRACK_OFFSET, 'zero width');
    equal(MenuLayout.checkboxOffset(0, -10), MenuLayout.checkboxOffset(0, 0), 'negative width is clamped');
  }

  /** A row that is too wide still fits the content area. */
  static function keepsLongRowsOnScreen():Void
  {
    for (viewport in [1280, 1707, 1720, 2560])
    {
      final contentLeft:Float = Math.max(0, (viewport - 1280) / 2);
      for (width in [-5, 0, 10, 400, 900, 1280, 2400])
      {
        final left:Float = MenuLayout.centeredStart(width, viewport, contentLeft);
        check(left >= contentLeft, 'row $width on $viewport starts inside the content area');
        check(left <= viewport, 'row $width on $viewport starts on screen');
      }
    }
  }
}
