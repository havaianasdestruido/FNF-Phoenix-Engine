package shaders;

import flixel.system.FlxAssets.FlxShader;

class InvertShader extends FlxShader
{
  @:glFragmentSource('
    #pragma header

    void main()
    {
        // Was a helper inverting rgb plus a follow-up write inverting the
        // alpha again: net effect is all four channels inverted, one op.
        gl_FragColor = vec4(1.0) - texture2D(bitmap, openfl_TextureCoordv);
    }')
  public function new()
  {
    super();
  }
}
