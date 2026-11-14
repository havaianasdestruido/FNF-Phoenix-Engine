package shaders;

import backend.FlxFixedShader;

/**
 * Silhouette: the sprite is flattened to a single colour while its alpha (and
 * therefore its shape) is kept, which is what a backlit or shadowed character
 * needs.
 *
 * Ported from Mario Madness' `SilhouetteShader`:
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/SilhouetteShader.hx
 *
 * Differences from the port source, all of them deliberate:
 * - the colour uniform is `uColor` and the mix amount `uAmount`, both set by
 *   `shaders.SilhouetteEffect` (which takes a `FlxColor`);
 * - `uAmount` is clamped in the shader, so the upstream `update()` wrapper that
 *   added to the amount and wrapped it below 1.0 is no longer needed;
 * - every literal is a float literal.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 *
 * This is a per-sprite shader first: put it on a `Character`
 * (`boyfriend.shader = effect.shader`) or on any `FlxSprite`. It also works as a
 * camera filter, where it flattens everything that camera draws.
 */
class SilhouetteShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// The flat colour the sprite is reduced to, in 0.0-1.0 channels.
	uniform vec3 uColor;

	// How much of the original picture is replaced: 0.0 is untouched,
	// 1.0 is a pure silhouette.
	uniform float uAmount;

	void main()
	{
		vec4 orig = flixel_texture2D(bitmap, openfl_TextureCoordv);
		// Upstream mixes toward `uColor * orig.a`, which keeps the semi-transparent
		// edge pixels of an antialiased sprite darker than the body.
		vec3 flat = uColor * orig.a;
		gl_FragColor = vec4(mix(orig.rgb, flat, clamp(uAmount, 0.0, 1.0)), orig.a);
	}
	')

  public function new()
  {
    super();
    uColor.value = [0.0, 0.0, 0.0];
    uAmount.value = [1.0];
  }
}
