package shaders;

import backend.FlxFixedShader;

/**
 * Steady VHS tape fuzz: rows wobble by a smooth simplex-noise offset, the three
 * channels are split horizontally, and a hard scanline pattern darkens the
 * picture. No glitch bursts, no vertical roll — the tape is old, not broken.
 *
 * Ported from Mario Madness' `VCRMario85` (after https://www.shadertoy.com/view/ldXGW4),
 * named here for what it does rather than for the song it was written for:
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/VCRMario85.hx
 * The 2D simplex noise is the ashima/webgl-noise implementation the port source
 * borrowed (https://github.com/ashima/webgl-noise/blob/master/src/noise2D.glsl).
 *
 * This is the part of that shader `shaders.VCRDistortionShader` does not already
 * do. VCRDistortion's movement is a time-windowed burst (`onOff()`) plus a
 * vertical roll, and it always pays for seven fetches and a contrast curve; this
 * one is a constant low-amplitude wobble in three fetches. For the curved frame
 * that used to ship next to it (`VCRBorder`), see `shaders.VCRBorderShader`.
 *
 * Differences from the port source, all of them deliberate:
 * - the wobble, the channel split, the scanline depth and its frequency are
 *   uniforms (`uFuzz`, `uSplit`, `uScanline`, `uScanlineFrequency`) instead of
 *   hardcoded literals, and each pass is skipped when its uniform is 0;
 * - the alpha fetch was dropped: the port source sampled the same coordinate
 *   twice, once for green and once for alpha;
 * - `texture()` became `flixel_texture2D()`, so the flixel colour transform is
 *   applied and the source stays valid on GLSL ES 1.00;
 * - every literal is a float literal.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 *
 * Animated: `shaders.VCRFuzzEffect` advances `uTime` every frame.
 */
class VCRFuzzShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// Seconds since the effect started.
	uniform float uTime;

	// Multiplier on the tape wobble: 1.0 matches upstream, 0.0 stops the rows
	// moving.
	uniform float uFuzz;

	// Horizontal channel separation in UV units (0.003 upstream).
	uniform float uSplit;

	// How much the scanline pattern darkens the picture (0.04 upstream).
	uniform float uScanline;

	// Scanline frequency in rows across the picture (800.0 upstream).
	uniform float uScanlineFrequency;

	vec3 mod289(vec3 x)
	{
		return x - floor(x * (1.0 / 289.0)) * 289.0;
	}

	vec2 mod289(vec2 x)
	{
		return x - floor(x * (1.0 / 289.0)) * 289.0;
	}

	vec3 permute(vec3 x)
	{
		return mod289(((x * 34.0) + 1.0) * x);
	}

	// 2D simplex noise (ashima/webgl-noise).
	float snoise(vec2 v)
	{
		const vec4 C = vec4(0.211324865405187, // (3.0 - sqrt(3.0)) / 6.0
			0.366025403784439, // 0.5 * (sqrt(3.0) - 1.0)
			-0.577350269189626, // -1.0 + 2.0 * C.x
			0.024390243902439); // 1.0 / 41.0

		// First corner.
		vec2 i = floor(v + dot(v, C.yy));
		vec2 x0 = v - i + dot(i, C.xx);

		// Other corners. The step() form ashima documents as the alternative to
		// a ternary on vectors, which some GLSL ES 1.00 drivers reject.
		float corner = step(x0.y, x0.x);
		vec2 i1 = vec2(corner, 1.0 - corner);
		vec4 x12 = x0.xyxy + C.xxzz;
		x12.xy -= i1;

		// Permutations.
		i = mod289(i);
		vec3 p = permute(permute(i.y + vec3(0.0, i1.y, 1.0)) + i.x + vec3(0.0, i1.x, 1.0));

		vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
		m = m * m;
		m = m * m;

		// Gradients: 41 points uniformly over a line, mapped onto a diamond.
		vec3 x = 2.0 * fract(p * C.www) - 1.0;
		vec3 h = abs(x) - 0.5;
		vec3 ox = floor(x + 0.5);
		vec3 a0 = x - ox;

		// Normalise gradients implicitly by scaling m.
		m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

		vec3 g;
		g.x = a0.x * x0.x + h.x * x0.y;
		g.yz = a0.yz * x12.xz + h.yz * x12.yw;
		return 130.0 * dot(m, g);
	}

	void main()
	{
		vec2 uv = openfl_TextureCoordv;

		// Two octaves of noise: a fast fine wobble and a slow wide one.
		float xOffset = (snoise(vec2(uTime * 15.0, uv.y * 80.0)) * 0.0005
			+ snoise(vec2(uTime * 1.0, uv.y * 25.0)) * 0.001) * uFuzz;

		vec4 green = flixel_texture2D(bitmap, vec2(uv.x + xOffset, uv.y));
		vec3 color = green.rgb;

		if (uSplit != 0.0)
		{
			color.r = flixel_texture2D(bitmap, vec2(uv.x + xOffset - uSplit, uv.y)).r;
			color.b = flixel_texture2D(bitmap, vec2(uv.x + xOffset + uSplit, uv.y)).b;
		}

		if (uScanline != 0.0)
			color -= uScanline * sin(uv.y * uScanlineFrequency);

		gl_FragColor = vec4(color, green.a);
	}
	')

  public function new()
  {
    super();
    uTime.value = [0.0];
    uFuzz.value = [1.0];
    uSplit.value = [0.003];
    uScanline.value = [0.04];
    uScanlineFrequency.value = [800.0];
  }
}
