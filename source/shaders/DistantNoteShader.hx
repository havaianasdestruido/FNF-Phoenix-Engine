package shaders;

import backend.FlxFixedShader;

/**
 * Perspective distortion for the note/strum camera, ported from Doido Engine's
 * `backend.shaders.DistantNoteShader` (Apache-2.0):
 * https://github.com/DoidoTeam/FNF-Doido-Engine/blob/main/source/backend/shaders/DistantNoteShader.hx
 *
 * Phoenix uses FlxFixedShader so the same GLSL also works on OpenGL ES.
 */
class DistantNoteShader
{
  public var shader(default, null):DistantNoteShaderData = new DistantNoteShaderData();
  public var downscroll(default, set):Bool = false;

  public function new()
  {
    downscroll = false;
  }

  function set_downscroll(value:Bool):Bool
  {
    downscroll = value;
    shader.uDownscroll.value = [value];
    return value;
  }
}

class DistantNoteShaderData extends FlxFixedShader
{
  @:glFragmentSource('
    #pragma header

    uniform bool uDownscroll;

    void main()
    {
      vec2 uv = openfl_TextureCoordv.xy;
      float actualY = uDownscroll ? (1.0 - uv.y) : uv.y;

      // Algebraically identical to the Doido pixel-space offset, without
      // multiplying and dividing by the camera resolution every fragment.
      uv.x += ((actualY - 0.42) / 0.8) * (uv.x - 0.5);
      gl_FragColor = flixel_texture2D(bitmap, uv);
    }')
  public function new()
  {
    super();
  }
}
