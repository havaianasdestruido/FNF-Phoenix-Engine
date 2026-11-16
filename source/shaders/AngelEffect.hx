package shaders;

/** Animated pixelated channel distortion. */
class AngelEffect extends Effect
{
  public var shader:AngelShader = new AngelShader();
  public var strength(get, set):Float;
  public var pixelSize(get, set):Float;

  public function new(strength:Float = 0.0, pixelSize:Float = 1.0)
  {
    this.strength = strength;
    this.pixelSize = pixelSize;
    EffectTicker.add(update);
  }
  public function update(elapsed:Float):Void shader.update(elapsed);
  function get_strength():Float return shader.strength;
  function set_strength(v:Float):Float return shader.strength = Math.isFinite(v) ? Math.max(0.0, v) : 0.0;
  function get_pixelSize():Float return shader.pixelSize;
  function set_pixelSize(v:Float):Float return shader.pixelSize = Math.isFinite(v) ? Math.max(1.0, v) : 1.0;
}
