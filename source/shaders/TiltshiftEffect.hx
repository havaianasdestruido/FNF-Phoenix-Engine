package shaders;

class TiltshiftEffect extends Effect
{
  public var shader:Tiltshift;

  /**
   * Executes the `new` operation.
   * @param blurAmount Input value for `blurAmount`.
   * @param center Input value for `center`.
   */
  public function new(blurAmount:Float, center:Float)
  {
    shader = new Tiltshift();
    shader.bluramount.value = [blurAmount];
    shader.center.value = [center];
  }
}
