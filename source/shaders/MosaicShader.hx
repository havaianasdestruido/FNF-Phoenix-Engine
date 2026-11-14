package shaders;

import backend.FlxFixedShader;

/**
 * Mosaic / pixelate: the picture is quantised into blocks, each one showing the
 * texel at its lower-left corner. This is the classic HaxeFlixel mosaic demo
 * shader, and what Mario Madness wraps as its `SMWPixelBlurShader`.
 *
 * Ported from Mario Madness' `openfl/MosaicShader.hx`:
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/openfl/MosaicShader.hx
 *
 * Differences from the port source, all of them deliberate:
 * - `uBlocksize` is clamped to a 1 pixel minimum in the shader as well as in
 *   `shaders.MosaicEffect`. Upstream documents that setting it to 0 turns the
 *   screen black: that is the divide-by-zero in `openfl_TextureSize / uBlocksize`
 *   producing NaN coordinates, and clamping removes the trap;
 * - `openfl_TextureSize` is clamped to a 1 pixel minimum for the same reason;
 * - every literal is a float literal.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 *
 * One fetch per pixel, so this is one of the cheapest effects here.
 */
class MosaicShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// Block size in render-target pixels, per axis. 1.0 changes nothing;
	// 8.0 turns the picture into 8x8 blocks.
	uniform vec2 uBlocksize;

	void main()
	{
		vec2 texSize = max(openfl_TextureSize, vec2(1.0));
		vec2 blocks = texSize / max(uBlocksize, vec2(1.0));
		gl_FragColor = flixel_texture2D(bitmap, floor(openfl_TextureCoordv * blocks) / blocks);
	}
	')

  public function new()
  {
    super();
    uBlocksize.value = [1.0, 1.0];
  }
}
