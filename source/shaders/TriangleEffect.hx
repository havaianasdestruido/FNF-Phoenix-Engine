package shaders;

class TriangleEffect extends Effect
{
  public var shader:TriangleShader = new TriangleShader();

  public function new(rotx:Float, roty:Float)
  {
    shader.rotX.value = [rotx];
    shader.rotY.value = [roty];
  }
}
