package shaders;

import flixel.system.FlxAssets.FlxShader;

class ChromaticAberrationShader extends FlxShader
{
  @:glFragmentSource('
		#pragma header

		uniform float rOffset;
		uniform float gOffset;
		uniform float bOffset;

		void main()
		{
			vec2 uv = openfl_TextureCoordv.st;
			vec4 col2 = texture2D(bitmap, uv - vec2(gOffset, 0.0));
			// The fourth, centered fetch only supplied the alpha channel. When
			// gOffset is 0 (what ChromaticAberrationEffect always sets), col2 is
			// already the centered texel, so reuse its alpha and skip the fetch.
			// The branch is on a uniform, so it costs nothing per-pixel.
			float alpha = (gOffset == 0.0) ? col2.a : texture2D(bitmap, uv).a;
			gl_FragColor = vec4(
				texture2D(bitmap, uv - vec2(rOffset, 0.0)).r,
				col2.g,
				texture2D(bitmap, uv - vec2(bOffset, 0.0)).b,
				alpha);
		}')
  public function new()
  {
    super();
  }
}
