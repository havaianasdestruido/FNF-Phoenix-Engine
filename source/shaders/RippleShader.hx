package shaders;

import backend.FlxFixedShader;

/**
 * Water ripple: the picture is displaced by a layered simplex-noise field that
 * scrolls over time, so it reads as a reflection on moving water.
 *
 * Ported from Mario Madness' `RippleShader`, itself the shadertoy at
 * https://www.shadertoy.com/view/XtsSzN:
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/RippleShader.hx
 *
 * Differences from the port source, all of them deliberate:
 * - `turbulence()` runs 4 octaves instead of 8. The upstream cost was twelve
 *   3D simplex evaluations per pixel (two `fBm` calls plus two `turbulence`
 *   calls); this halves it, which is what makes the effect usable on the
 *   low-end devices this engine targets. The first four octaves carry the
 *   visible wave, the rest added sub-pixel detail;
 * - the strength, time scale and coordinate scale are uniforms (`uStrength`,
 *   `uSpeed`, `uScale`) instead of hardcoded locals, and the commented-out
 *   `colIntensity` / `warpIntensity` uniforms were dropped;
 * - the loops compare with `<` against a `const int`, the form every GLSL ES
 *   1.00 driver accepts, instead of `!=`;
 * - every literal is a float literal, and the alpha of the displaced sample is
 *   preserved instead of being rewritten from a `vec3`.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 *
 * Animated: `shaders.RippleEffect` advances `uTime` every frame.
 */
class RippleShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// Seconds since the effect started.
	uniform float uTime;

	// Displacement strength, in thousandths of the screen (10.0 upstream).
	uniform float uStrength;

	// How fast the water moves (0.5 upstream).
	uniform float uSpeed;

	// Coordinate scale of the noise field: bigger is smaller, tighter ripples.
	uniform float uScale;

	vec3 mod289(vec3 x)
	{
		return x - floor(x * (1.0 / 289.0)) * 289.0;
	}

	vec4 mod289(vec4 x)
	{
		return x - floor(x * (1.0 / 289.0)) * 289.0;
	}

	vec4 permute(vec4 x)
	{
		return mod289(((x * 34.0) + 1.0) * x);
	}

	vec4 taylorInvSqrt(vec4 r)
	{
		return 1.79284291400159 - 0.85373472095314 * r;
	}

	// 3D simplex noise (ashima/webgl-noise).
	float snoise(vec3 v)
	{
		const vec2 C = vec2(1.0 / 6.0, 1.0 / 3.0);
		const vec4 D = vec4(0.0, 0.5, 1.0, 2.0);

		// First corner.
		vec3 i = floor(v + dot(v, C.yyy));
		vec3 x0 = v - i + dot(i, C.xxx);

		// Other corners.
		vec3 g = step(x0.yzx, x0.xyz);
		vec3 l = 1.0 - g;
		vec3 i1 = min(g.xyz, l.zxy);
		vec3 i2 = max(g.xyz, l.zxy);

		vec3 x1 = x0 - i1 + C.xxx;
		vec3 x2 = x0 - i2 + C.yyy;
		vec3 x3 = x0 - D.yyy;

		// Permutations.
		i = mod289(i);
		vec4 p = permute(permute(permute(
					i.z + vec4(0.0, i1.z, i2.z, 1.0))
				+ i.y + vec4(0.0, i1.y, i2.y, 1.0))
			+ i.x + vec4(0.0, i1.x, i2.x, 1.0));

		// Gradients: 7x7 points over a square, mapped onto an octahedron.
		float n_ = 0.142857142857; // 1.0 / 7.0
		vec3 ns = n_ * D.wyz - D.xzx;

		vec4 j = p - 49.0 * floor(p * ns.z * ns.z);

		vec4 x_ = floor(j * ns.z);
		vec4 y_ = floor(j - 7.0 * x_);

		vec4 x = x_ * ns.x + ns.yyyy;
		vec4 y = y_ * ns.x + ns.yyyy;
		vec4 h = 1.0 - abs(x) - abs(y);

		vec4 b0 = vec4(x.xy, y.xy);
		vec4 b1 = vec4(x.zw, y.zw);

		vec4 s0 = floor(b0) * 2.0 + 1.0;
		vec4 s1 = floor(b1) * 2.0 + 1.0;
		vec4 sh = -step(h, vec4(0.0));

		vec4 a0 = b0.xzyw + s0.xzyw * sh.xxyy;
		vec4 a1 = b1.xzyw + s1.xzyw * sh.zzww;

		vec3 p0 = vec3(a0.xy, h.x);
		vec3 p1 = vec3(a0.zw, h.y);
		vec3 p2 = vec3(a1.xy, h.z);
		vec3 p3 = vec3(a1.zw, h.w);

		// Normalise gradients.
		vec4 norm = taylorInvSqrt(vec4(dot(p0, p0), dot(p1, p1), dot(p2, p2), dot(p3, p3)));
		p0 *= norm.x;
		p1 *= norm.y;
		p2 *= norm.z;
		p3 *= norm.w;

		// Mix final noise value.
		vec4 m = max(0.6 - vec4(dot(x0, x0), dot(x1, x1), dot(x2, x2), dot(x3, x3)), 0.0);
		m = m * m;
		return 42.0 * dot(m * m, vec4(dot(p0, x0), dot(p1, x1), dot(p2, x2), dot(p3, x3)));
	}

	// Fractal Brownian motion: the slow, rolling part of the water.
	float fBm(vec3 coords)
	{
		const int octaves = 2;
		const float smoothness = 2.0;
		const float lacunarity = 2.0;

		float result = 0.0;
		float totalAmplitude = 0.0;

		for (int o = 0; o < octaves; o++)
		{
			float amplitude = pow(lacunarity, -smoothness * float(o));
			result += snoise(coords) * amplitude;
			totalAmplitude += amplitude;
			coords *= lacunarity;
		}

		return result / totalAmplitude;
	}

	// Summed absolute noise: the choppy detail on top of the swell.
	float turbulence(vec3 coords)
	{
		const int octaves = 4;
		const float f_low = 1.0;

		float t = 0.0;

		for (int o = 0; o < octaves; o++)
		{
			float f = f_low * pow(2.0, float(o));
			t += abs(snoise(coords)) / f;
			coords *= 2.0;
		}

		return t;
	}

	void main()
	{
		float time = uTime * uSpeed;
		vec2 uv = openfl_TextureCoordv;

		vec2 x_offset = vec2(123.456, 0.0);
		vec2 y_offset = vec2(349.234, 1704.2);

		// Two independent fields, one per axis, so the ripple does not read as a
		// single scrolling texture.
		float xo = fBm(vec3((uv + x_offset) * uScale, time));
		float xt = turbulence(vec3((uv + x_offset) * (5.0 * uScale), time));
		float yo = fBm(vec3((uv + y_offset) * uScale, time));
		float yt = turbulence(vec3((uv + y_offset) * (5.0 * uScale), time));

		// Upstream divides the UV by 1000 here, so uStrength is in thousandths
		// of the screen.
		vec2 pixel = uv / 1000.0;
		vec2 offset = uStrength * vec2(xo + xt, yo + yt) * pixel;

		gl_FragColor = flixel_texture2D(bitmap, uv + offset);
	}
	')

  public function new()
  {
    super();
    uTime.value = [0.0];
    uStrength.value = [10.0];
    uSpeed.value = [0.5];
    uScale.value = [1.0];
  }
}
