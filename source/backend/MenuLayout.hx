package backend;

/**
 * Horizontal layout math for the settings menus.
 *
 * The options lists used to hang off the left edge of the screen: the label at a
 * fixed `+290` and the value text or checkbox at a fixed offset from it. On a
 * wide window that leaves a hole on the right, and the value column moves from
 * row to row whenever the labels differ in length.
 *
 * The list is now one centered block made of up to three columns:
 *
 * ```
 *   [checkbox][gap][label          ][gap][value]
 * ```
 *
 * The widest row decides how wide the block is and the block is centered on the
 * window (`centeredStart`). Everything inside it is placed from the block's left
 * edge with the helpers below, so the columns line up between rows.
 *
 * The module is deliberately free of Flixel/OpenFL imports, so the rules can be
 * checked in the Haxe interpreter: `tests/haxe/MenuLayoutSpec.hx`.
 */
class MenuLayout
{
  /**
   * Horizontal distance between two parts of a row.
   *
   * Large enough that a checkbox does not touch its label and a value text does
   * not read as part of the label, small enough that three columns still fit on
   * a 1280-wide window next to the longest option names.
   */
  public static inline var PART_GAP:Float = 36;

  /**
   * Width of the whole list, as a block of three columns.
   *
   * Each optional column is added once, plus one `PART_GAP` per boundary between
   * two present columns, which is exactly `rowWidth` for the widest row.
   *
   * @param widestLabel   Width of the longest option name.
   * @param valueColumn   Width of the widest value any option can show.
   * @param checkboxWidth Width of a checkbox sprite.
   * @param hasCheckboxes Whether any row of the list draws a checkbox.
   */
  public static function blockWidth(widestLabel:Float, valueColumn:Float, checkboxWidth:Float, hasCheckboxes:Bool):Float
  {
    return rowWidth(widestLabel, valueColumn, checkboxWidth, valueColumn > 0, hasCheckboxes);
  }

  /**
   * Width of one row, given the measured widths of its parts.
   *
   * Only the parts that are present count, and each pair of neighbours is
   * separated by one `PART_GAP`.
   *
   * @param labelWidth    Width of the option name (always present).
   * @param valueWidth    Width of the current value text.
   * @param checkboxWidth Width of the checkbox sprite.
   * @param hasValue      Whether the row draws a value text.
   * @param hasCheckbox   Whether the row draws a checkbox.
   */
  public static function rowWidth(labelWidth:Float, valueWidth:Float, checkboxWidth:Float, hasValue:Bool, hasCheckbox:Bool):Float
  {
    var parts:Int = 1; // the label
    var width:Float = Math.max(0, labelWidth);

    if (hasCheckbox)
    {
      width += Math.max(0, checkboxWidth);
      parts++;
    }
    if (hasValue)
    {
      width += Math.max(0, valueWidth);
      parts++;
    }

    return width + PART_GAP * (parts - 1);
  }

  /**
   * Left edge of a block of `blockWidth` on a viewport of `viewportWidth`.
   *
   * Centered, but never left of `contentLeft` (the left edge of the centered
   * 16:9 playfield): a block wider than the screen is pushed right into the
   * visible area instead of hanging unusable off the left edge.
   *
   * @param blockWidth    Total width of the row.
   * @param viewportWidth Logical width of the window.
   * @param contentLeft   Left edge of the content area (`ScreenLayout.contentLeft`).
   */
  public static function centeredStart(blockWidth:Float, viewportWidth:Float, contentLeft:Float):Float
  {
    final width:Float = Math.max(0, blockWidth);
    return Math.max(contentLeft, (viewportWidth - width) / 2);
  }

  /**
   * Column origin of the row labels.
   *
   * Right after the checkbox column (plus its gap) when any row has a checkbox,
   * so every label of the list starts on the same X whether or not its own row
   * carries a box.
   */
  public static function labelColumn(blockLeft:Float, checkboxColumn:Float, hasCheckboxes:Bool):Float
  {
    return hasCheckboxes ? blockLeft + Math.max(0, checkboxColumn) + PART_GAP : blockLeft;
  }

  /**
   * Column origin of the value texts.
   *
   * Right of the widest label (plus its gap), so values line up between rows
   * instead of following each row's own text.
   */
  public static function valueColumn(labelColumnLeft:Float, widestLabel:Float):Float
  {
    return labelColumnLeft + Math.max(0, widestLabel) + PART_GAP;
  }

  /**
   * `offsetX` that puts a checkbox of `thisWidth` one gap before `labelLeft`.
   *
   * `CheckboxThingie` draws itself at `sprTracker.x - 130`, so its own offset has
   * to cancel that anchor:
   *
   * ```
   * labelLeft + CHECKBOX_TRACK_OFFSET + offsetX = labelLeft - PART_GAP - thisWidth
   * offsetX = -PART_GAP - thisWidth - CHECKBOX_TRACK_OFFSET
   * ```
   *
   * @param labelLeft Where the labels of the list start.
   * @param thisWidth Width of this particular checkbox.
   */
  public static function checkboxOffset(labelLeft:Float, thisWidth:Float):Float
  {
    return -PART_GAP - Math.max(0, thisWidth) - CHECKBOX_TRACK_OFFSET;
  }

  /**
   * Distance `objects.CheckboxThingie` keeps between itself and its tracker,
   * as `sprTracker.x + CHECKBOX_TRACK_OFFSET`.
   *
   * Duplicated on purpose: the sprite exposes no constant for it, and the layout
   * math above has to cancel it out. `tests/haxe/MenuLayoutSpec.hx` pins the
   * value; changing it in `CheckboxThingie` means changing it here too.
   */
  public static inline var CHECKBOX_TRACK_OFFSET:Float = -130;
}
