package shaders;

import backend.FlxFixedShader;

/**
 * The VCR/CRT frame on its own: a curved screen, a rounded corner vignette and a
 * black bezel where the curve pushes the picture off screen. No glitch, no colour
 * bleed, no noise — two texture fetches per pixel.
 *
 * Ported from Mario Madness' `VCRBorder` (after https://www.shadertoy.com/view/Ms23DR
 * and https://www.shadertoy.com/view/MsXGD4):
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/VCRBorder.hx
 *
 * This is the part of that pair `shaders.VCRDistortionShader` does not already do:
 * VCRDistortion can curve the screen (`perspectiveOn`) and darken it
 * (`vignetteOn`), but it always runs its seven-fetch glitch and RGB smear on top,
 * so there was no way to get just the frame. `VCRMario85`, the other shader in
 * that pair, is `shaders.VCRFuzzShader`.
 *
 * Differences from the port source, all of them deliberate:
 * - the curve, the vignette and the bezel are switchable (`uCurve`, `uVignette`,
 *   `uBorder`);
 * - the vignette is a `smoothstep` on the distance from the centre instead of
 *   `pow(cos(...), 2.5)`, which raised a negative base to a fractional power and
 *   returned NaN on strict drivers;
 * - the off-screen sample coordinate is clamped before the fetch, so the bezel
 *   does not depend on the texture's wrap mode, and the two identical fetches of
 *   the port source became one;
 * - every literal is a float literal.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 */
class VCRBorderShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// Curvature amount: 0.0 is a flat screen, 1.0 the upstream VCR curve.
	uniform float uCurve;

	// Corner darkening, 0.0 (none) to 1.0 (black corners).
	uniform float uVignette;

	// Whether the area the curve pushes off screen is black (the bezel) or
	// shows the clamped edge pixel.
	uniform bool uBorder;

	vec2 curve(vec2 uv)
	{
		uv = (uv - 0.5) * 2.0;
		uv *= 1.0 + 0.1 * uCurve;
		uv.x *= 1.0 + pow(abs(uv.y) / 5.0, 2.0) * uCurve;
		uv.y *= 1.0 + pow(abs(uv.x) / 4.0, 2.0) * uCurve;
		uv = uv * 0.5 + 0.5;
		return uv * (1.0 - 0.08 * uCurve) + 0.04 * uCurve;
	}

	float vignette(vec2 uv)
	{
		// 0.0 until well past the middle of the screen, 1.0 in the corners: the
		// rounded-rectangle falloff of the port source, which its exponent of 160
		// made very square.
		float radius = length((uv - 0.5) * 2.0);
		return clamp(1.0 - uVignette * smoothstep(0.9, 1.45, radius), 0.0, 1.0);
	}

	void main()
	{
		vec2 uv = curve(openfl_TextureCoordv);
		bool outside = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;

		vec4 col = flixel_texture2D(bitmap, clamp(uv, 0.0, 1.0));
		if (outside && uBorder)
			col.rgb = vec3(0.0);

		col.rgb *= vignette(openfl_TextureCoordv);
		gl_FragColor = col;
	}
	')

  public function new()
  {
    super();
    uCurve.value = [1.0];
    uVignette.value = [1.0];
    uBorder.value = [true];
  }
}
