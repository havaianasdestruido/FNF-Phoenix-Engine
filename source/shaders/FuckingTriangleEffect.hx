package shaders;

class FuckingTriangleEffect extends Effect
{
  public var shader:FuckingTriangle = new FuckingTriangle();

  /**
   * Executes the `new` operation.
   * @param rotx Input value for `rotx`.
   * @param roty Input value for `roty`.
   */
  public function new(rotx:Float, roty:Float)
  {
    shader.rotX.value = [rotx];
    shader.rotY.value = [roty];
  }
}
