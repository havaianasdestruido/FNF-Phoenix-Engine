package shaders;

class InvertColorsEffect extends Effect
{
  public var shader:InvertShader = new InvertShader();

  /**
   * Executes the `new` operation.
   * @param lockAlpha Input value for `lockAlpha`.
   */
  public function new(lockAlpha)
  {
    //	shader.lockAlpha.value = [lockAlpha];
  }
}
