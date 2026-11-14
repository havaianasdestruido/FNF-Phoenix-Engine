package shaders;

import backend.FlxFixedShader;

/**
 * Brightness and contrast: contrast pivots around mid grey, brightness scales the
 * result. A dimmer for a whole camera or for one sprite.
 *
 * Ported from Mario Madness' `BrightnessContrastShader`:
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/BrightnessContrastShader.hx
 *
 * Differences from the port source, all of them deliberate:
 * - the uniforms are `uBrightness` / `uContrast`;
 * - fully transparent pixels keep their black RGB. Contrast moves every pixel
 *   away from 0.5, including the alpha-zero ones a camera filter leaves around
 *   the HUD, which would otherwise come back as a grey box;
 * - every literal is a float literal.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 *
 * One fetch and a few multiplies per pixel: this is the cheapest effect here, and
 * the one to reach for when a stage only needs to be dimmed (TODO §22.2 "Stage
 * dim / stage brightness") without a black overlay sprite.
 */
class BrightnessContrastShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// Multiplier on the result: 1.0 is unchanged, 0.5 is half as bright,
	// 0.0 is black.
	uniform float uBrightness;

	// Multiplier on the distance from mid grey: 1.0 is unchanged, 0.0 is flat
	// grey, 2.0 is twice as punchy.
	uniform float uContrast;

	void main()
	{
		vec4 col = flixel_texture2D(bitmap, openfl_TextureCoordv);
		vec3 adjusted = ((col.rgb - 0.5) * max(uContrast, 0.0) + 0.5) * max(uBrightness, 0.0);
		// mix/step instead of a ternary on vectors: branch-free, and it keeps
		// GLSL ES 1.00 drivers that dislike non-scalar selection happy.
		gl_FragColor = vec4(mix(col.rgb, adjusted, step(0.0001, col.a)), col.a);
	}
	')

  public function new()
  {
    super();
    uBrightness.value = [1.0];
    uContrast.value = [1.0];
  }
}
