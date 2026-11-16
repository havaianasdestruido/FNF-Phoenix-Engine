package shaders;

import backend.FlxFixedShader;

/**
 * Repeats the camera image as a grid, with optional horizontal mirroring.
 * Ported from Mario Madness' CamDupeShader (Apache-2.0):
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/CamDupeShader.hx
 * The redundant checker calculation was removed, scalar uniform writes fixed,
 * and mirrorS is initialized. Sampling still preserves the repeated image's alpha.
 */
class CamDupeShader extends FlxFixedShader
{
  public var mult(get, set):Float;
  public var mirror(get, set):Bool;

  @:glFragmentSource('
    #pragma header
    uniform float multi;
    uniform bool mirrorS;
    void main()
    {
      vec2 uv = fract(openfl_TextureCoordv * multi);
      if (mirrorS) uv.x = 1.0 - uv.x;
      gl_FragColor = flixel_texture2D(bitmap, uv);
    }
  ')

  public function new()
  {
    super();
    multi.value = [1.0];
    mirrorS.value = [false];
  }

  function get_mult():Float return multi.value[0];
  function set_mult(v:Float):Float { multi.value[0] = v; return v; }
  function get_mirror():Bool return mirrorS.value[0];
  function set_mirror(v:Bool):Bool { mirrorS.value[0] = v; return v; }
}
