package shaders;

import flixel.system.FlxAssets.FlxShader;

/**
 * Distant-note perspective ported from Doido Engine's DistantNoteShader:
 * https://github.com/DoidoTeam/FNF-Doido-Engine/blob/main/source/backend/shaders/DistantNoteShader.hx
 * Apply to a camera containing the note field, not to individual notes.
 */
class DistantNoteShader extends FlxShader
{
  @:glFragmentSource('
    #pragma header
    uniform bool uDownscroll;

    void main()
    {
      vec2 uv = openfl_TextureCoordv.xy;
      float actualY = uDownscroll ? 1.0 - uv.y : uv.y;
      actualY -= 0.42;
      uv.x += (actualY / 0.8) * (openfl_TextureCoordv.x - 0.5);

      // Do not repeat edge pixels outside the note camera source texture.
      if (uv.x < 0.0 || uv.x > 1.0)
        gl_FragColor = vec4(0.0);
      else
        gl_FragColor = flixel_texture2D(bitmap, uv);
    }
  ')
  public function new(downscroll:Bool = false)
  {
    super();
    uDownscroll.value = [downscroll];
  }
}
