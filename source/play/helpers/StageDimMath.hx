package play.helpers;

/**
 * Renderer-free rules behind the **Stage dim** preference
 * (`ClientPrefs.stageDim`, Options -> Visuals and UI).
 *
 * Stage dim draws one black, screen-fixed sprite on `camGame` only, so the
 * stage and the characters get darker while the notes, the strums and the HUD
 * stay bright: notes are routed to `camNotes` (Distant Notes) or `camHUD`, and
 * neither camera draws the overlay. Pixel stages and normal stages behave the
 * same, because nothing touches the stage art itself.
 *
 * A `scrollFactor` of 0 pins the quad to the screen, but Flixel scales camera
 * content by `camGame.zoom` around the camera centre and `doTwist` rotates the
 * camera display, so the quad has to be *smaller* than the viewport when the
 * camera zooms in and larger again when it rotates. The functions here compute
 * that size in camera-space units.
 *
 * Everything is pure math so `tests/haxe/run-stage-dim.sh` can execute it in
 * the Haxe interpreter without Flixel/OpenFL/Lime.
 */
class StageDimMath
{
  /**
   * Largest alpha the option allows. 100% would black out the stage entirely
   * and hide the characters, which defeats the point of dimming instead of
   * hiding; the row stops here.
   */
  public static inline var MAX_ALPHA:Float = 0.9;

  /** Step the options row moves in while a direction is held or pressed. */
  public static inline var STEP:Float = 0.05;

  /** The 0% default: the feature is off and costs nothing. */
  public static inline var MIN_ALPHA:Float = 0;

  /**
   * Extra coverage on each axis, as a fraction of the viewport.
   *
   * Camera shake (`FlxCamera.shake`) moves the camera display itself, which can
   * pull the rendered view off one edge by a few pixels before the next frame
   * repositions the quad; rounding the quad to whole pixels does the same by up
   * to one pixel. A margin only makes the quad bigger, and a bigger solid quad
   * costs nothing extra, so this errs on the side of covering.
   */
  public static inline var SAFETY_MARGIN:Float = 0.1;

  /**
   * Clamps a saved or script-provided value into the usable range.
   *
   * `ClientPrefs` values come from hand-edited save files and from scripts, so
   * every consumer has to tolerate `NaN` and out-of-range numbers instead of
   * trusting the Options row. Anything unusable becomes 0 (off), which is also
   * the default for existing players.
   *
   * @param value raw preference value, in 0..1.
   * @return an alpha between `MIN_ALPHA` and `MAX_ALPHA`.
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

  /** Whether the overlay has to be drawn at all for this preference value. */
  public static inline function isVisible(value:Float):Bool
    return alpha(value) > MIN_ALPHA;

  /**
   * Zoom used for the coverage math.
   *
   * Flixel treats a camera zoom of 0 as "the camera's default zoom", and a
   * negative or absurd value would produce a zero/negative-size quad. Anything
   * that is not a sane positive number falls back to 1:1.
   */
  public static function safeZoom(zoom:Float):Float
  {
    if (zoom != zoom || zoom <= 0) return 1;
    return zoom;
  }

  /**
   * Size, in camera-space units, of a quad that covers a camera's view.
   *
   * At 1:1 and no rotation this is exactly the camera size (plus
   * `SAFETY_MARGIN`). A camera zoomed in by 2 shows half of each axis around
   * the camera centre, so the quad is half as wide and half as tall; zooming
   * out grows it. Rotation happens around that same centre
   * (`FlxCamera.set_angle()` rotates the camera display, whose content is
   * centred on it), so a rotated view still fits in the bounding box of the
   * tilted rectangle: `w·|cos| + h·|sin|` on each axis.
   *
   * @param cameraWidth  camera width in game pixels (`FlxG.width` in gameplay).
   * @param cameraHeight camera height in game pixels (`FlxG.height`).
   * @param zoom         gameplay camera zoom (`camGame.zoom`); 0 = default.
   * @param angle        camera rotation in degrees (`camGame.angle`).
   * @return a positive size in camera-space units.
   */
  public static function coverageSize(cameraWidth:Int, cameraHeight:Int, zoom:Float, angle:Float):{width:Float, height:Float}
  {
    final width:Float = cameraWidth > 0 ? cameraWidth : 1;
    final height:Float = cameraHeight > 0 ? cameraHeight : 1;
    final scale:Float = (1 + SAFETY_MARGIN) / safeZoom(zoom);

    final radians:Float = safeAngle(angle) * Math.PI / 180;
    final cos:Float = Math.abs(Math.cos(radians));
    final sin:Float = Math.abs(Math.sin(radians));

    return {
      width: (width * cos + height * sin) * scale,
      height: (width * sin + height * cos) * scale
    };
  }

  /**
   * Top-left corner, in camera-space units, of a quad of `coverageSize()`.
   *
   * Centred on the camera's own centre: a `scrollFactor` 0 sprite ignores the
   * scroll, and the camera scales and rotates around that centre, so centring
   * is what keeps every edge covered at any zoom.
   */
  public static function coveragePosition(cameraWidth:Int, cameraHeight:Int, size:{width:Float, height:Float}):{x:Float, y:Float}
  {
    final width:Float = cameraWidth > 0 ? cameraWidth : 1;
    final height:Float = cameraHeight > 0 ? cameraHeight : 1;

    return {
      x: (width - size.width) / 2,
      y: (height - size.height) / 2
    };
  }

  /** Rotation in degrees, with non-finite values treated as "no rotation". */
  public static function safeAngle(angle:Float):Float
  {
    if (angle != angle) return 0;
    return angle;
  }
}
