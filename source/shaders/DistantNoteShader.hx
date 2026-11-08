package shaders;

import flixel.system.FlxAssets.FlxShader;

/**
 * Distant-note "highway": the texture is skewed toward a horizon so notes look
 * like they recede into the distance, Guitar Hero style.
 *
 * Ported from FNF-Doido-Engine's `DistantNoteShader` (itself adapted from a
 * HaxeFlixel demo), with the two perspective constants lifted into uniforms.
 *
 * This samples the whole render target it is attached to, so it belongs on a
 * camera filter (see `shaders.DistantNoteEffect`), not on a single sprite.
 */
class DistantNoteShader extends FlxShader
{
  @:glFragmentSource('
	#pragma header

	// Position of the horizon: the Y the highway converges at.
	// 0.42 matches the original Doido shader.
	uniform float uPivot;

	// How quickly the perspective opens up; larger is narrower.
	// 0.8 matches the original Doido shader.
	uniform float uSpread;

	// Mirrors the perspective for downscroll so the highway still recedes
	// toward the top of the screen.
	uniform bool uDownscroll;

	void main()
	{
		vec2 uv = openfl_TextureCoordv;
		float actualY = uv.y;
		if (uDownscroll)
			actualY = 1.0 - uv.y;
		actualY -= uPivot;

		// The original scaled a fragCoord difference by the resolution here;
		// both terms reduce to UV space: (fragCoord.x - res.x * 0.5) / res.x
		// is exactly uv.x - 0.5.
		uv.x += (actualY / uSpread) * (uv.x - 0.5);

		gl_FragColor = flixel_texture2D(bitmap, uv);
	}
	')

  public function new(downscroll:Bool = false)
  {
    super();
    uPivot.value = [0.42];
    uSpread.value = [0.8];
    uDownscroll.value = [downscroll];
  }
}
