package shaders;


import flixel.system.FlxAssets.FlxShader;

class BuildingShader extends FlxShader
{
  @:glFragmentSource('
    #pragma header
    uniform float alphaValue;
    void main()
    {

      vec4 color = flixel_texture2D(bitmap,openfl_TextureCoordv);
      if (color.a > 0.0)
        color-=alphaValue;

      gl_FragColor = color;
    }
  ')
  public function new()
  {
    super();
  }
}
