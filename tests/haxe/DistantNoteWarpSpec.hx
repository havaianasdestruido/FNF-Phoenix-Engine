import shaders.DistantNoteWarp;

/**
 * Contract tests for `shaders.DistantNoteWarp`, the math behind the Distant Note
 * port from Doido Engine.
 *
 * The module is Flixel-free on purpose, so the rules can be checked on the Haxe
 * interpreter without a GL context.
 *
 *     bash tests/haxe/run-distant-note.sh
 */
class DistantNoteWarpSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function near(actual:Float, expected:Float, label:String, tolerance:Float = 0.000001):Void
  {
    if (Math.abs(actual - expected) > tolerance)
      throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    matchesOriginalShader();
    flipsForDownscroll();
    pivotsOnTheHorizon();
    warpsTowardsTheCentre();
    staysInsideTheTexture();
    pinsTheOriginalConstants();
  }

  /**
   * The Haxe side reproduces Doido's GLSL exactly:
   *
   * ```glsl
   * float actualY = uv.y;
   * if(uDownscroll) actualY = 1.0 - uv.y;
   * actualY -= 0.42;
   * uv.x += (actualY / 0.8) * (uv.x - 0.5);
   * ```
   */
  static function matchesOriginalShader():Void
  {
    // Hand-computed values from the original formula, upscroll.
    for (sample in [
      {x: 0.5, y: 0.0, expected: 0.0}, // top centre: no sideways pull
      {x: 0.25, y: 0.0, expected: (0.0 - 0.42) / 0.8 * (0.25 - 0.5)},
      {x: 0.25, y: 0.42, expected: 0.0}, // on the horizon: untouched
      {x: 0.75, y: 1.0, expected: (1.0 - 0.42) / 0.8 * (0.75 - 0.5)},
      {x: 1.0, y: 1.0, expected: (1.0 - 0.42) / 0.8 * 0.5}
    ])
    {
      near(DistantNoteWarp.horizontalOffset(sample.x, sample.y, false), sample.expected, 'upscroll ${sample.x},${sample.y}');
    }
  }

  /** Downscroll mirrors the lane, so the horizon flips with it. */
  static function flipsForDownscroll():Void
  {
    near(DistantNoteWarp.orientedY(0.1, false), 0.1, 'upscroll keeps Y');
    near(DistantNoteWarp.orientedY(0.1, true), 0.9, 'downscroll mirrors Y');

    // A pixel at the horizon is untouched in both directions.
    near(DistantNoteWarp.distanceToHorizon(DistantNoteWarp.HORIZON, false), 0, 'upscroll horizon');
    near(DistantNoteWarp.distanceToHorizon(1 - DistantNoteWarp.HORIZON, true), 0, 'downscroll horizon');

    // Mirroring is its own inverse, which is what makes the parameter settable
    // while the camera is alive.
    for (y in [0.0, 0.25, 0.5, 0.9, 1.0])
      near(DistantNoteWarp.orientedY(DistantNoteWarp.orientedY(y, true), true), y, 'mirror twice at $y');
  }

  /** The horizon is the pivot: pixels there never move. */
  static function pivotsOnTheHorizon():Void
  {
    for (x in [0.0, 0.1, 0.5, 0.9, 1.0])
    {
      near(DistantNoteWarp.horizontalOffset(x, DistantNoteWarp.HORIZON, false), 0, 'horizon pixel $x does not move');
      near(DistantNoteWarp.horizontalOffset(x, 1 - DistantNoteWarp.HORIZON, true), 0, 'downscroll horizon pixel $x does not move');
    }
  }

  /**
   * The warp is a shear around the centre column: pixels on one side sample from
   * further out, which spreads the lane cone outwards as it leaves the horizon.
   *
   * The sign matters. `offset = (distance / cone) * (uv.x - 0.5)` makes a pixel
   * left of centre sample further left and a pixel right of centre sample
   * further right, so the two lanes fan out from the vanishing point instead of
   * collapsing into it.
   */
  static function warpsTowardsTheCentre():Void
  {
    // Left of centre samples further left (negative offset); right of centre
    // samples further right (positive offset).
    check(DistantNoteWarp.horizontalOffset(0.25, 1.0, false) < 0, 'left of centre samples further left');
    check(DistantNoteWarp.horizontalOffset(0.75, 1.0, false) > 0, 'right of centre samples further right');

    // The shear grows with the distance from the horizon.
    final close:Float = Math.abs(DistantNoteWarp.horizontalOffset(0.25, 0.6, false));
    final far:Float = Math.abs(DistantNoteWarp.horizontalOffset(0.25, 1.0, false));
    check(far > close, 'shear grows with distance from the horizon');

    // The centre column is the vanishing point: it never moves sideways.
    for (y in [0.0, 0.2, 0.5, 0.8, 1.0])
      near(DistantNoteWarp.horizontalOffset(0.5, y, false), 0, 'centre column at $y');

    // Symmetric pixels get symmetric offsets.
    near(DistantNoteWarp.horizontalOffset(0.25, 0.9, false), -DistantNoteWarp.horizontalOffset(0.75, 0.9, false), 'left/right symmetry');
  }

  /** The sample never leaves the texture, so no transparent hole can appear. */
  static function staysInsideTheTexture():Void
  {
    // A zero cone cannot be divided by: it is treated as "no warp", not as a
    // division by zero that would poison the whole frame.
    for (y in [0.0, 0.42, 1.0])
      near(DistantNoteWarp.horizontalOffset(1.0, y, false, DistantNoteWarp.HORIZON, 0), 0, 'zero cone does not warp');

    for (x in [-0.5, 0.0, 0.25, 0.5, 0.75, 1.0, 1.5])
      for (y in [-0.5, 0.0, 0.42, 0.9, 1.0, 1.5])
        for (downscroll in [true, false])
        {
          final uv = DistantNoteWarp.sampleUv(x, y, downscroll);
          check(uv.x >= 0 && uv.x <= 1, 'sample X in range for $x,$y');
          check(uv.y >= 0 && uv.y <= 1, 'sample Y in range for $x,$y');
        }
  }

  /** Constants kept identical to Doido Engine's shader. */
  static function pinsTheOriginalConstants():Void
  {
    near(DistantNoteWarp.HORIZON, 0.42, 'horizon');
    near(DistantNoteWarp.CONE, 0.8, 'cone');
    check(DistantNoteWarp.requiresMiddleScroll(), 'the warp needs middlescroll, like the original');
  }
}
