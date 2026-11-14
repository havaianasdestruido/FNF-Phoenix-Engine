package shaders;

/**
 * Screen curvature + scanlines + shadow mask + vignette, the classic CRT
 * television look (see `shaders.CRTShader`).
 *
 * Ported from Mario Madness (`CRTShader`), Timothy Lottes' public-domain CRT
 * shader; credits and the list of local changes are on the shader class.
 *
 * Usage:
 * ```haxe
 * var crt = new shaders.CRTEffect();
 * game.addShaderToCamera('game', crt);
 * crt.vignette = 0.5;      // darker corners
 * crt.curve = 0.0;         // flat screen, scanlines only
 * ```
 *
 * From Lua/Python/HScript: `addCRTEffect('game')`.
 *
 * The effect is stateless in time (no `update()`), so it can be created in any
 * state and it never registers on a frame callback.
 */
class CRTEffect extends Effect
{
  public var shader:CRTShader = new CRTShader();

  /** Screen curvature multiplier: 0.0 is flat, 1.0 the classic CRT bulge, 2.0 twice as warped. */
  public var curve(default, set):Float = 1.0;

  /** Scanline falloff hardness. Negative only; -8.0 soft, -16.0 medium, -20.0 hard. Clamped to -0.5 at most. */
  public var scanlineHardness(default, set):Float = -8.0;

  /** Pixel hardness inside a scanline: -2.0 soft, -4.0 hard. Clamped to -0.5 at most. */
  public var pixelHardness(default, set):Float = -2.0;

  /** Shadow mask amount, 0.0 (no mask) to 1.0 (full phosphor stripes). */
  public var mask(default, set):Float = 1.0;

  /** Corner darkening, 0.0 (none) to 1.0 (black corners). */
  public var vignette(default, set):Float = 0.25;

  /** Emulated resolution as a fraction of the render target: 0.5 doubles the scanline grid. */
  public var resolutionScale(default, set):Float = 0.5;

  /**
   * @param curve Screen curvature multiplier (0.0 = flat screen).
   * @param scanlineHardness Scanline falloff, negative values only (-8.0 soft, -16.0 medium).
   * @param pixelHardness Pixel hardness inside a scanline (-2.0 soft, -4.0 hard).
   * @param mask Shadow mask amount, 0.0 to 1.0.
   * @param vignette Corner darkening, 0.0 to 1.0.
   * @param resolutionScale Emulated resolution as a fraction of the render target.
   */
  public function new(curve:Float = 1.0, scanlineHardness:Float = -8.0, pixelHardness:Float = -2.0, mask:Float = 1.0, vignette:Float = 0.25,
      resolutionScale:Float = 0.5)
  {
    this.curve = curve;
    this.scanlineHardness = scanlineHardness;
    this.pixelHardness = pixelHardness;
    this.mask = mask;
    this.vignette = vignette;
    this.resolutionScale = resolutionScale;
  }

  function set_curve(v:Float):Float
  {
    curve = v;
    // The base warp is Lottes' 1/32 by 1/24; `curve` scales both axes, and a
    // negative multiplier would fold the screen inside out.
    final amount:Float = Math.max(0.0, v);
    shader.uWarp.value[0] = amount / 32.0;
    shader.uWarp.value[1] = amount / 24.0;
    return v;
  }

  function set_scanlineHardness(v:Float):Float
  {
    scanlineHardness = v;
    shader.uHardScan.value[0] = clampHardness(v);
    return v;
  }

  function set_pixelHardness(v:Float):Float
  {
    pixelHardness = v;
    shader.uHardPix.value[0] = clampHardness(v);
    return v;
  }

  function set_mask(v:Float):Float
  {
    mask = v;
    shader.uMask.value[0] = v;
    return v;
  }

  function set_vignette(v:Float):Float
  {
    vignette = v;
    shader.uVignette.value[0] = v;
    return v;
  }

  function set_resolutionScale(v:Float):Float
  {
    resolutionScale = v;
    shader.uResolutionScale.value[0] = Math.max(0.0, v);
    return v;
  }

  /**
   * Gaussian hardness feeds `exp2(scale * d * d)`, so a positive value blows the
   * weights up instead of narrowing them. Anything above -0.5 is treated as the
   * softest setting.
   */
  static function clampHardness(v:Float):Float
  {
    if (Math.isNaN(v)) return -8.0;
    return Math.min(v, -0.5);
  }
}
