package play.helpers;

/**
 * Renderer-free rules behind the **Lane underlay** preference
 * (`ClientPrefs.laneUnderlayAlpha`, Options -> Visuals and UI).
 *
 * The underlay is one black, screen-fixed-width quad drawn behind the
 * player's lanes (see `play.helpers.PlayStateLaneUnderlay`). It exists so
 * the arrows stay readable over busy stages; it never covers the strums,
 * the notes or the HUD, which draw on the same camera above it.
 *
 * Everything here is pure math so `tests/haxe/run-lane-underlay.sh` can
 * execute it in the Haxe interpreter without Flixel/OpenFL/Lime.
 */
class LaneUnderlayMath
{
  /**
   * Largest alpha the option allows. 100% is a solid black strip, which is
   * meaningful here (unlike Stage dim, where blacking the characters out
   * defeats the point): the notes and strums render on top of the strip.
   */
  public static inline var MAX_ALPHA:Float = 1.0;

  /** Step the options row moves in while a direction is held or pressed. */
  public static inline var STEP:Float = 0.05;

  /** The 0% default: the feature is off and costs nothing. */
  public static inline var MIN_ALPHA:Float = 0;

  /** Horizontal padding on each side of the lane span, in game pixels. */
  public static inline var PAD:Float = 10;

  /**
   * Clamps a saved or script-provided value into the usable range.
   *
   * `ClientPrefs` values come from hand-edited save files and from scripts, so
   * every consumer has to tolerate `NaN` and out-of-range numbers instead of
   * trusting the Options row. Anything unusable becomes 0 (off), which is also
   * the default for existing players.
   */
  public static function alpha(value:Float):Float
  {
    // `value != value` is the NaN test that also compiles on static targets,
    // where a `Float` can never be compared to `null`.
    if (value != value) return MIN_ALPHA;
    if (value <= MIN_ALPHA) return MIN_ALPHA;
    if (value >= MAX_ALPHA) return MAX_ALPHA;
    return value;
  }

  /** Whether the strip has to be drawn at all for this preference value. */
  public static inline function isVisible(value:Float):Bool
    return alpha(value) > MIN_ALPHA;

  /**
   * Horizontal span of the strip, given the outermost edges of the player's
   * lanes (first lane's left edge, last lane's right edge), before padding.
   *
   * The strum field is never empty once the countdown starts, but the caller
   * may still hold garbage from a partially built state (or from a hand-set
   * value), so NaN in means a zero-width strip at the origin out. Padded edges
   * are returned in order; an inverted pair is swapped rather than rejected.
   *
   * @param firstLaneX  left edge of the leftmost player lane.
   * @param lastLaneRight right edge of the rightmost player lane.
   * @param padding     pixels to extend the strip on each side; negative or
   *                    NaN values fall back to `PAD`.
   */
  public static function laneRect(firstLaneX:Float, lastLaneRight:Float, ?padding:Float):{x:Float, width:Float}
  {
    final pad:Float = (padding == null || padding != padding || padding < 0) ? PAD : padding;

    if (firstLaneX != firstLaneX || lastLaneRight != lastLaneRight)
      return {x: 0, width: 0};

    var left:Float = firstLaneX;
    var right:Float = lastLaneRight;

    // Normalise before padding so argument order does not matter: an inverted
    // pair yields exactly what the swapped pair would.
    if (right < left)
    {
      final tmp:Float = left;
      left = right;
      right = tmp;
    }

    left -= pad;
    right += pad;

    return {x: left, width: Math.max(1, right - left)};
  }
}
