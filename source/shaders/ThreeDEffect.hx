package shaders;

class ThreeDEffect extends Effect
{
  public var shader:ThreeDShader = new ThreeDShader();

  /**
   * Executes the `new` operation.
   * @param xrotation Input value for `xrotation`.
   * @param yrotation Input value for `yrotation`.
   * @param zrotation Input value for `zrotation`.
   * @param depth Input value for `depth`.
   */
  public function new(xrotation:Float = 0, yrotation:Float = 0, zrotation:Float = 0, depth:Float = 0)
  {
    shader.xrot.value = [xrotation];
    shader.yrot.value = [yrotation];
    shader.zrot.value = [zrotation];
    shader.dept.value = [depth];
  }
}
