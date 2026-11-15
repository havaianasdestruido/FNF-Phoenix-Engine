package shaders;

/** Camera grid duplication. `mult` is the number of repeats per axis. */
class CamDupeEffect extends Effect
{
  public var shader:CamDupeShader = new CamDupeShader();
  public var mult(get, set):Float;
  public var mirror(get, set):Bool;

  public function new(mult:Float = 1.0, mirror:Bool = false)
  {
    this.mult = mult;
    this.mirror = mirror;
  }
  function get_mult():Float return shader.mult;
  function set_mult(v:Float):Float return shader.mult = Math.isFinite(v) ? Math.max(0.0, v) : 1.0;
  function get_mirror():Bool return shader.mirror;
  function set_mirror(v:Bool):Bool return shader.mirror = v;
}
