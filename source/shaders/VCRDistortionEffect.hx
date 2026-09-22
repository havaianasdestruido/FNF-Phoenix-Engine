package shaders;

import openfl.Lib;

import play.PlayState;

class VCRDistortionEffect extends Effect
{
  public var shader:VCRDistortionShader = new VCRDistortionShader();

  /**
   * Executes the `new` operation.
   * @param glitchFactor Input value for `glitchFactor`.
   * @param distortion Input value for `distortion`.
   * @param perspectiveOn Input value for `perspectiveOn`.
   * @param vignetteMoving Input value for `vignetteMoving`.
   */
  public function new(glitchFactor:Float, distortion:Bool = true, perspectiveOn:Bool = true, vignetteMoving:Bool = true)
  {
    shader.iTime.value = [0.0];
    shader.vignetteOn.value = [true];
    shader.perspectiveOn.value = [perspectiveOn];
    shader.distortionOn.value = [distortion];
    shader.scanlinesOn.value = [true];
    shader.vignetteMoving.value = [vignetteMoving];
    shader.glitchModifier.value = [glitchFactor];
    shader.iResolution.value = [Lib.current.stage.stageWidth, Lib.current.stage.stageHeight];
    PlayState.instance.shaderUpdates.push(update);
  }

  /**
   * Executes the `update` operation.
   * @param elapsed Input value for `elapsed`.
   * @return Result produced by `update`, when applicable.
   */
  public function update(elapsed:Float)
  {
    shader.iTime.value[0] += elapsed;
    shader.iResolution.value = [Lib.current.stage.stageWidth, Lib.current.stage.stageHeight];
  }

  /**
   * Executes the `setVignette` operation.
   * @param state Input value for `state`.
   * @return Result produced by `setVignette`, when applicable.
   */
  public function setVignette(state:Bool)
  {
    shader.vignetteOn.value[0] = state;
  }

  /**
   * Executes the `setPerspective` operation.
   * @param state Input value for `state`.
   * @return Result produced by `setPerspective`, when applicable.
   */
  public function setPerspective(state:Bool)
  {
    shader.perspectiveOn.value[0] = state;
  }

  /**
   * Executes the `setGlitchModifier` operation.
   * @param modifier Input value for `modifier`.
   * @return Result produced by `setGlitchModifier`, when applicable.
   */
  public function setGlitchModifier(modifier:Float)
  {
    shader.glitchModifier.value[0] = modifier;
  }

  /**
   * Executes the `setDistortion` operation.
   * @param state Input value for `state`.
   * @return Result produced by `setDistortion`, when applicable.
   */
  public function setDistortion(state:Bool)
  {
    shader.distortionOn.value[0] = state;
  }

  /**
   * Executes the `setScanlines` operation.
   * @param state Input value for `state`.
   * @return Result produced by `setScanlines`, when applicable.
   */
  public function setScanlines(state:Bool)
  {
    shader.scanlinesOn.value[0] = state;
  }

  /**
   * Executes the `setVignetteMoving` operation.
   * @param state Input value for `state`.
   * @return Result produced by `setVignetteMoving`, when applicable.
   */
  public function setVignetteMoving(state:Bool)
  {
    shader.vignetteMoving.value[0] = state;
  }
}
