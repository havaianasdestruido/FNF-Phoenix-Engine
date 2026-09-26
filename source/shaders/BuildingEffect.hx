package shaders;

class BuildingEffect
{
  public var shader:BuildingShader = new BuildingShader();

  /**
   * Executes the `new` operation.
*/
  public function new()
  {
    shader.alphaValue.value = [0.0];
  }

  /**
   * Executes the `addAlpha` operation.
   * @param alpha Input value for `alpha`.
   * @return Result produced by `addAlpha`, when applicable.
   */
  public function addAlpha(alpha:Float)
  {
    trace(shader.alphaValue.value[0]);
    shader.alphaValue.value[0] += alpha;
  }

  /**
   * Executes the `setAlpha` operation.
   * @param alpha Input value for `alpha`.
   * @return Result produced by `setAlpha`, when applicable.
   */
  public function setAlpha(alpha:Float)
  {
    shader.alphaValue.value[0] = alpha;
  }
}
