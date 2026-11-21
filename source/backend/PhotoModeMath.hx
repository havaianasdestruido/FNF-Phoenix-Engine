package backend;

/**
 * Camera math shared by Photo Mode and its interpreter-only regression spec.
 * The helpers do not depend on Flixel, so zoom bounds and center-preserving
 * camera moves can be checked without loading the renderer.
 */
class PhotoModeMath
{
  /** Smallest usable camera zoom; values below this expose impractical ranges. */
  public static inline var MIN_ZOOM:Float = 0.25;

  /** Largest usable camera zoom; values above this magnify pixels excessively. */
  public static inline var MAX_ZOOM:Float = 4.0;

  /** Screen-space pan speed in logical pixels per second at 1x zoom. */
  public static inline var PAN_SPEED:Float = 700.0;

  /** Faster movement multiplier while Shift is held. */
  public static inline var FAST_PAN_MULTIPLIER:Float = 3.0;

  /**
   * Clamps zoom to the supported range; non-finite input falls back to 1x.
   *
   * @param zoom Requested zoom, including values loaded from the live camera.
   * @return A finite zoom between {@link MIN_ZOOM} and {@link MAX_ZOOM}.
   */
  public static function clampZoom(zoom:Float):Float
  {
    if (!Math.isFinite(zoom)) return 1.0;
    return Math.max(MIN_ZOOM, Math.min(MAX_ZOOM, zoom));
  }

  /**
   * Calculates a zoom change while retaining FlxCamera's world-space center.
   *
   * FlxCamera's zoom transform is centered on `scroll + viewport / 2`, so the
   * scroll coordinates do not need to move when the zoom changes. Keeping
   * that convention here prevents an unintended pan during zoom.
   *
   * @param scrollX Current horizontal camera scroll.
   * @param scrollY Current vertical camera scroll.
   * @param newZoom Requested camera zoom; it is clamped before calculation.
   * @return Unchanged scroll coordinates and the bounded zoom.
   */
  public static function zoomAtCenter(scrollX:Float, scrollY:Float,
    newZoom:Float):{scrollX:Float, scrollY:Float, zoom:Float}
  {
    return {
      scrollX: scrollX,
      scrollY: scrollY,
      zoom: clampZoom(newZoom)
    };
  }

  /**
   * Returns world-space camera movement for a screen-space pan input.
   *
   * @param elapsed Seconds since the previous update.
   * @param zoom   Current zoom, used to keep the screen-space pan speed stable.
   * @param fast   Whether the fast-pan modifier is held.
   * @return Non-negative world units to move along one camera axis.
   */
  public static function panDistance(elapsed:Float, zoom:Float, fast:Bool):Float
  {
    if (!Math.isFinite(elapsed) || elapsed <= 0) return 0;
    final multiplier:Float = fast ? FAST_PAN_MULTIPLIER : 1.0;
    return elapsed * PAN_SPEED * multiplier / clampZoom(zoom);
  }
}
