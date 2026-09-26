package shaders;

import flixel.system.FlxAssets.FlxShader;

class BloomEffect extends Effect
{
  public var shader:BloomShader = new BloomShader();

  /**
   * Executes the `new` operation.
   * @param blurSize Input value for `blurSize`.
   * @param intensity Input value for `intensity`.
   */
  public function new(blurSize:Float, intensity:Float)
  {
    shader.blurSize.value = [blurSize];
    shader.intensity.value = [intensity];
  }
}
