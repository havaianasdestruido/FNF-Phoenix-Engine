package shaders;

/**
 * Curved VCR frame with a corner vignette and a black bezel, and nothing else —
 * no glitch, no colour bleed (see `shaders.VCRBorderShader`).
 *
 * Ported from Mario Madness (`VCRBorder`); credits, the comparison with
 * `shaders.VCRDistortionShader` and the list of local changes are on the shader
 * class.
 *
 * Usage:
 * ```haxe
 * var frame = new shaders.VCRBorderEffect();
 * game.addShaderToCamera('game', frame);
 * frame.curve = 0.5;       // a gentler bulge
 * frame.border = false;    // let the edges smear instead of going black
 * ```
 *
 * From Lua/Python/HScript: `addVCRBorderEffect('game')`. Reach for
 * `addVCREffect` instead when the picture should also glitch.
 */
class VCRBorderEffect extends Effect
{
  public var shader:VCRBorderShader = new VCRBorderShader();

  /** Curvature amount: 0.0 is a flat screen, 1.0 the upstream VCR curve. */
  public var curve(default, set):Float = 1.0;

  /** Corner darkening, 0.0 (none) to 1.0 (black corners). */
  public var vignette(default, set):Float = 1.0;

  /** Whether the area the curve pushes off screen is black instead of a smeared edge. */
  public var border(default, set):Bool = true;

  /**
   * @param curve Curvature amount (0.0 = flat screen).
   * @param vignette Corner darkening, 0.0 to 1.0.
   * @param border Whether the off-screen area is black.
   */
  public function new(curve:Float = 1.0, vignette:Float = 1.0, border:Bool = true)
  {
    this.curve = curve;
    this.vignette = vignette;
    this.border = border;
  }

  function set_curve(v:Float):Float
  {
    curve = v;
    // A negative curve folds the screen inside out and samples it twice over.
    shader.uCurve.value[0] = Math.isNaN(v) ? 0.0 : Math.max(0.0, v);
    return v;
  }

  function set_vignette(v:Float):Float
  {
    vignette = v;
    shader.uVignette.value[0] = Math.isNaN(v) ? 0.0 : Math.max(0.0, v);
    return v;
  }

  function set_border(v:Bool):Bool
  {
    border = v;
    shader.uBorder.value[0] = v;
    return v;
  }
}
