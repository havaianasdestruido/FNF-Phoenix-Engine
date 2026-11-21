import backend.PhotoModeMath;

/** Regression checks for Photo Mode's camera zoom and pan calculations. */
class PhotoModeSpec
{
  /** Number of assertions completed by this spec. */
  static var checks:Int = 0;

  /** Runs zoom bounds, center preservation, and pan-speed checks. */
  static function main():Void
  {
    near(PhotoModeMath.clampZoom(1.5), 1.5, 'an in-range zoom is unchanged');
    near(PhotoModeMath.clampZoom(0), PhotoModeMath.MIN_ZOOM, 'zero zoom clamps to the minimum');
    near(PhotoModeMath.clampZoom(9), PhotoModeMath.MAX_ZOOM, 'large zoom clamps to the maximum');
    near(PhotoModeMath.clampZoom(Math.NaN), 1, 'non-finite zoom falls back to 1x');

    final zoomed = PhotoModeMath.zoomAtCenter(100, 200, 2);
    near(zoomed.zoom, 2, 'requested zoom is applied');
    near(zoomed.scrollX, 100, 'zoom-in keeps horizontal scroll unchanged');
    near(zoomed.scrollY, 200, 'zoom-in keeps vertical scroll unchanged');

    final restored = PhotoModeMath.zoomAtCenter(zoomed.scrollX, zoomed.scrollY, 1);
    near(restored.scrollX, 100, 'zoom-out keeps horizontal scroll unchanged');
    near(restored.scrollY, 200, 'zoom-out keeps vertical scroll unchanged');

    near(PhotoModeMath.panDistance(1, 1, false), PhotoModeMath.PAN_SPEED,
      'one second at 1x uses the regular screen-space speed');
    near(PhotoModeMath.panDistance(1, 2, false), PhotoModeMath.PAN_SPEED / 2,
      'zoomed-in pan moves fewer world units');
    near(PhotoModeMath.panDistance(1, 1, true), PhotoModeMath.PAN_SPEED * PhotoModeMath.FAST_PAN_MULTIPLIER,
      'the fast-pan modifier increases speed');
    near(PhotoModeMath.panDistance(-1, 1, false), 0, 'negative elapsed time cannot reverse pan');

    Sys.println('Photo Mode checks: ' + checks + ' passed');
  }

  /** Compares a floating-point camera result against an expected value. */
  static function near(actual:Float, expected:Float, description:String):Void
  {
    checks++;
    if (Math.abs(actual - expected) > 0.0001)
      throw description + ': expected ' + expected + ', got ' + actual;
  }
}
