package shaders;

/** Blur and vertical shading used for Mario Madness' 2D-in-3D scene. */
class TwoDinThreeDEffect extends Effect
{
  public var shader:TwoDinThreeD = new TwoDinThreeD();
  public var blur(get, set):Float;
  public var yOffset(get, set):Float;

  public function new(blur:Float = 0.0, yOffset:Float = 0.0)
  {
    this.blur = blur;
    this.yOffset = yOffset;
  }
  function get_blur():Float return shader.blur.value[0];
  function set_blur(v:Float):Float return shader.blur.value[0] = Math.isFinite(v) ? Math.max(0.0, Math.min(1.0, v)) : 0.0;
  function get_yOffset():Float return shader.yOff.value[0];
  function set_yOffset(v:Float):Float return shader.yOff.value[0] = Math.isFinite(v) ? v : 0.0;
}
