package shaders;

class ScanlineEffect extends Effect
{
  public var shader:Scanline;

  /**
   * Executes the `new` operation.
   * @param lockAlpha Input value for `lockAlpha`.
   */
  public function new(lockAlpha)
  {
    shader = new Scanline();
    shader.lockAlpha.value = [lockAlpha];
  }
}
