package shaders;

class ChromaticAberrationEffect extends Effect
{
  public var shader:ChromaticAberrationShader;

  public function new(offset:Float = 0.00)
  {
    shader = new ChromaticAberrationShader();
    shader.rOffset.value = [offset];
    shader.gOffset.value = [0.0];
    shader.bOffset.value = [-offset];
  }

  public function setChrome(chromeOffset:Float):Void
  {
    // Mutate the arrays allocated in the constructor: stages call this as
    // often as every beat, and the old form allocated three Arrays per call.
    // The null checks keep this working if `shader` was replaced.
    if (shader.rOffset.value == null)
      shader.rOffset.value = [chromeOffset];
    else
      shader.rOffset.value[0] = chromeOffset;
    if (shader.gOffset.value == null)
      shader.gOffset.value = [0.0];
    else
      shader.gOffset.value[0] = 0.0;
    if (shader.bOffset.value == null)
      shader.bOffset.value = [chromeOffset * -1];
    else
      shader.bOffset.value[0] = chromeOffset * -1;
  }
}
