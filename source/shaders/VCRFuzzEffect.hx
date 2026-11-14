package shaders;

/**
 * Steady VHS tape fuzz: row wobble, channel split and a hard scanline pattern,
 * without the glitch bursts of `shaders.VCRDistortionEffect` (see
 * `shaders.VCRFuzzShader`).
 *
 * Ported from Mario Madness (`VCRMario85`); credits, the comparison with
 * `VCRDistortionShader` and the list of local changes are on the shader class.
 *
 * Usage:
 * ```haxe
 * var tape = new shaders.VCRFuzzEffect();
 * game.addShaderToCamera('game', tape);
 * tape.fuzz = 3.0;      // a badly stored tape
 * tape.split = 0.0;     // no channel separation
 * ```
 *
 * From Lua/Python/HScript: `addVCRFuzzEffect('game')`. Pair it with
 * `addVCRBorderEffect` for the frame the upstream shader shipped with. Works
 * outside a song too (title screen, menus) through `shaders.EffectTicker`.
 */
class VCRFuzzEffect extends Effect
{
  public var shader:VCRFuzzShader = new VCRFuzzShader();

  /** Seconds the effect has been running. */
  public var time(get, set):Float;

  /** Multiplier on the tape wobble: 1.0 matches upstream, 0.0 stops the rows moving. */
  public var fuzz(default, set):Float = 1.0;

  /** Horizontal channel separation in UV units (0.003 matches upstream, 0.0 disables the two extra fetches). */
  public var split(default, set):Float = 0.003;

  /** How much the scanline pattern darkens the picture (0.04 matches upstream). */
  public var scanline(default, set):Float = 0.04;

  /** Scanline frequency in rows across the picture (800.0 matches upstream). */
  public var scanlineFrequency(default, set):Float = 800.0;

  /**
   * @param fuzz Multiplier on the tape wobble.
   * @param split Horizontal channel separation in UV units.
   * @param scanline How much the scanline pattern darkens the picture.
   * @param scanlineFrequency Scanline frequency in rows across the picture.
   */
  public function new(fuzz:Float = 1.0, split:Float = 0.003, scanline:Float = 0.04, scanlineFrequency:Float = 800.0)
  {
    this.fuzz = fuzz;
    this.split = split;
    this.scanline = scanline;
    this.scanlineFrequency = scanlineFrequency;
    EffectTicker.add(update);
  }

  /** Advances `uTime`; called once per frame by `shaders.EffectTicker`. */
  public function update(elapsed:Float):Void
  {
    shader.uTime.value[0] += elapsed;
  }

  function get_time():Float
  {
    return shader.uTime.value[0];
  }

  function set_time(v:Float):Float
  {
    shader.uTime.value[0] = v;
    return v;
  }

  function set_fuzz(v:Float):Float
  {
    fuzz = v;
    shader.uFuzz.value[0] = Math.max(0.0, v);
    return v;
  }

  function set_split(v:Float):Float
  {
    split = v;
    shader.uSplit.value[0] = Math.max(0.0, v);
    return v;
  }

  function set_scanline(v:Float):Float
  {
    scanline = v;
    shader.uScanline.value[0] = Math.max(0.0, v);
    return v;
  }

  function set_scanlineFrequency(v:Float):Float
  {
    scanlineFrequency = v;
    shader.uScanlineFrequency.value[0] = Math.max(0.0, v);
    return v;
  }
}
