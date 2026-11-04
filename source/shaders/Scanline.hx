package shaders;

import flixel.system.FlxAssets.FlxShader;

class Scanline extends FlxShader
{
  @:glFragmentSource('
		#pragma header
		const float scale = 1.0;
	uniform bool lockAlpha;
		void main()
		{
			bool blackRow = mod(floor(openfl_TextureCoordv.y * openfl_TextureSize.y / scale), 2.0) == 0.0;
			// Black rows only need the texel for its alpha when lockAlpha is
			// on; with it off (the default) half the pixels skip the fetch.
			if (blackRow && !lockAlpha){
				gl_FragColor = vec4(0.0, 0.0, 0.0, 1.0);
				return;
			}
			vec4 texColor = texture2D(bitmap, openfl_TextureCoordv);
			gl_FragColor = blackRow ? vec4(0.0, 0.0, 0.0, texColor.a) : texColor;
		}')
  public function new()
  {
    super();
    lockAlpha.value = [false];
  }
}
