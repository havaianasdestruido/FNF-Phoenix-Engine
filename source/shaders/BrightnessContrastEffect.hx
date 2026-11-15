package shaders;

/**
 * Brightness and contrast for a camera or a sprite (see
 * `shaders.BrightnessContrastShader`).
 *
 * Ported from Mario Madness (`BrightnessContrastShader`); credits and the list of
 * local changes are on the shader class.
 *
 * Usage:
 * ```haxe
 * var dim = new shaders.BrightnessContrastEffect(0.6, 1.1);
 * game.addShaderToCamera('game', dim);   // a darker, punchier stage
 * dim.brightness = 1.0;                  // lights back up
 * ```
 *
 * From Lua/Python/HScript: `addBrightnessContrastEffect('game', 0.6, 1.1)`.
 * Brightness below 1.0 is the shader-side way of doing the stage dim idea in
 * TODO §22.2: it only touches the camera it is attached to, so notes and the HUD
 * stay bright when it sits on `camGame`.
 */
class BrightnessContrastEffect extends Effect
{
  public var shader:BrightnessContrastShader = new BrightnessContrastShader();

  /** Multiplier on the result: 1.0 unchanged, 0.5 half as bright, 0.0 black. */
  public var brightness(default, set):Float = 1.0;

  /** Multiplier on the distance from mid grey: 1.0 unchanged, 0.0 flat grey. */
  public var contrast(default, set):Float = 1.0;

  /**
   * @param brightness Multiplier on the result (1.0 = unchanged).
   * @param contrast Multiplier on the distance from mid grey (1.0 = unchanged).
   */
  public function new(brightness:Float = 1.0, contrast:Float = 1.0)
  {
    this.brightness = brightness;
    this.contrast = contrast;
  }

  function set_brightness(v:Float):Float
  {
    brightness = v;
    // The shader clamps too; doing it here keeps the reported value honest and
    // stops a NaN from a script reaching the driver.
    shader.uBrightness.value[0] = Math.isNaN(v) ? 1.0 : Math.max(0.0, v);
    return v;
  }

  function set_contrast(v:Float):Float
  {
    contrast = v;
    shader.uContrast.value[0] = Math.isNaN(v) ? 1.0 : Math.max(0.0, v);
    return v;
  }
}
