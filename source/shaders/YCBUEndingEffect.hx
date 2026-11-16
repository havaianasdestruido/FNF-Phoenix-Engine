package shaders;

/** Animated line glitch and monochrome noise from You Can't Beat Us' ending. */
class YCBUEndingEffect extends Effect
{
  public var shader:YCBUEndingShader = new YCBUEndingShader();
  public var intensity(get, set):Float;
  public var seed(get, set):Float;

  public function new(intensity:Float = 0.0, seed:Float = 0.0)
  {
    this.intensity = intensity;
    this.seed = seed;
    EffectTicker.add(update);
  }
  public function update(elapsed:Float):Void shader.update(0.0, elapsed);
  function get_intensity():Float return shader.intensity.value[0];
  function set_intensity(v:Float):Float
  {
    return shader.intensity.value[0] = Math.isFinite(v) ? Math.max(0.0, Math.min(1.0, v)) : 0.0;
  }
  function get_seed():Float return shader.seed.value[0];
  function set_seed(v:Float):Float return shader.seed.value[0] = Math.isFinite(v) ? v : 0.0;
}
