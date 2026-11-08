package shaders;

/**
 * The numbers behind `shaders.DistantNoteShader`, free of Flixel/OpenFL imports.
 *
 * Doido Engine's shader warps the camera texture with four hardcoded constants
 * baked into the GLSL (`0.42`, `0.8`, and a `- 0.42` applied to a *mirrored* Y on
 * downscroll). Phoenix keeps the same picture but exposes the constants to Haxe
 * so they can be scaled with the playfield, be verified in
 * `tests/haxe/DistantNoteWarpSpec.hx`, and be applied to a camera whose size is
 * not necessarily 720 pixels tall.
 *
 * The warp is a horizontal shear around the centre of the screen:
 *
 * ```
 * uv.x += (distanceToHorizon / cone) * (uv.x - 0.5)
 * ```
 *
 * where `distanceToHorizon` is measured from the horizon line, which sits at
 * `HORIZON` of the texture above the bottom of the lane. Pixels on the horizon
 * do not move, pixels far from it are pulled towards the middle, and the result
 * reads as the lanes vanishing into the distance.
 *
 * The original GLSL (Doido Engine, GPL-3.0) is:
 *
 * ```glsl
 * float actualY = uv.y;
 * if(uDownscroll)
 *     actualY = (iResolution.y - (uv.y * iResolution.y)) / iResolution.y;
 * actualY -= 0.42;
 * uv.x += (actualY / 0.8) * (fragCoord.x - (iResolution.x * 0.5)) / iResolution.x;
 * ```
 */
class DistantNoteWarp
{
  /** Horizon line, as a fraction of the texture height (Doido's `0.42`). */
  public static inline var HORIZON:Float = 0.42;

  /** Cone slope; larger values warp less (Doido's `0.8`). */
  public static inline var CONE:Float = 0.8;

  /**
   * The Y coordinate the shader works with.
   *
   * Downscroll mirrors the lane, so texture-space Y is flipped to keep the
   * horizon on the side the notes come from.
   *
   * @param uvY      Texture Y of the pixel, `0` at the top.
   * @param downscroll Whether the chart scrolls downwards.
   */
  public static inline function orientedY(uvY:Float, downscroll:Bool):Float
  {
    return downscroll ? 1 - uvY : uvY;
  }

  /**
   * Distance from the horizon, as a fraction of the texture height.
   *
   * Positive on the strum side of the horizon, negative on the other side, and
   * exactly zero on the horizon itself: those pixels are never offset.
   */
  public static inline function distanceToHorizon(uvY:Float, downscroll:Bool, horizon:Float = HORIZON):Float
  {
    return orientedY(uvY, downscroll) - horizon;
  }

  /**
   * Horizontal texture offset applied to a pixel.
   *
   * @param uvX       Texture X of the pixel.
   * @param uvY       Texture Y of the pixel.
   * @param downscroll Whether the chart scrolls downwards.
   * @param horizon   Horizon line, as a fraction of the texture height.
   * @param cone      Cone slope, larger warps less.
   * @return The offset to add to `uvX`, in texture units.
   */
  public static function horizontalOffset(uvX:Float, uvY:Float, downscroll:Bool, horizon:Float = HORIZON, cone:Float = CONE):Float
  {
    final slope:Float = cone == 0 ? 0 : distanceToHorizon(uvY, downscroll, horizon) / cone;
    return slope * (uvX - 0.5);
  }

  /**
   * Where a pixel samples the texture, in texture units.
   *
   * The sample stays inside `[0, 1]` on both axes, because sampling outside the
   * camera texture would pick up the transparent clear colour and punch holes in
   * the playfield once the shader is applied to a scene that is not the whole
   * screen.
   */
  public static function sampleUv(uvX:Float, uvY:Float, downscroll:Bool, horizon:Float = HORIZON, cone:Float = CONE):{x:Float, y:Float}
  {
    final offset:Float = horizontalOffset(uvX, uvY, downscroll, horizon, cone);
    return {x: clamp01(uvX + offset), y: clamp01(uvY)};
  }

  /**
   * Whether the warp can be used with the current lane layout.
   *
   * The original engine forces middlescroll when this shader is on: with the
   * lanes on the screen edges the vanishing point falls outside the playfield,
   * so the two sides are warped in opposite directions and the notes lean away
   * from the centre.
   */
  public static inline function requiresMiddleScroll():Bool
  {
    return true;
  }

  /** Clamps a texture coordinate to the valid range. */
  public static inline function clamp01(value:Float):Float
  {
    return value < 0 ? 0 : (value > 1 ? 1 : value);
  }
}
