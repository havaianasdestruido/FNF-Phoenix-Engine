package shaders;

import backend.FlxFixedShader;

/**
 * CRT arcade-monitor look: a curved (warped) screen, scanline reconstruction,
 * an RGB shadow mask and a corner vignette.
 *
 * Ported from Mario Madness' `CRTShader`, itself Timothy Lottes' public-domain
 * "CRT styled scan-line" shader (https://www.shadertoy.com/view/4scSR8):
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/CRTShader.hx
 *
 * Differences from the port source, all of them deliberate:
 * - the emulated resolution follows the render target (`uResolutionScale`)
 *   instead of a fixed 512x448, so the scanline grid survives a window resize;
 * - alpha is preserved (taps are accumulated premultiplied and un-premultiplied
 *   on the way out) instead of being forced to 1.0, so the effect can sit on
 *   `camHUD` or on a single sprite without becoming an opaque box;
 * - `uMask` and `uVignette` amounts were added (0.0 disables each pass) and the
 *   unused `bar()` / `rand()` helpers were dropped;
 * - every literal is a float literal and `pow()` only ever sees a clamped,
 *   non-negative base, which strict GLSL ES drivers require.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 *
 * Costs eleven texture fetches per pixel (three horizontal Gaussian taps per
 * scanline, three scanlines). On the low-end devices this engine targets that is
 * a full-screen effect worth measuring before shipping in a mod: prefer it on
 * `camGame` alone rather than on every camera.
 */
class CRTShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// Emulated input resolution as a fraction of the render target: 0.5 makes
	// the scanline grid twice as coarse as the screen pixels. Clamped inside
	// emulatedResolution() so 0.0 cannot divide by zero.
	uniform float uResolutionScale;

	// Hardness of the scanline falloff. Negative values only: -8.0 is soft,
	// -16.0 medium, -20.0 hard. A positive value would make exp2() explode, so
	// CRTEffect clamps it.
	uniform float uHardScan;

	// Hardness of the pixels inside a scanline: -2.0 soft, -4.0 hard.
	uniform float uHardPix;

	// Screen warp (curvature) per axis. vec2(0.0) is a flat screen;
	// vec2(1.0 / 32.0, 1.0 / 24.0) is the classic CRT bulge.
	uniform vec2 uWarp;

	// Shadow mask: dark and light phosphor levels, and how much of the mask is
	// mixed in (0.0 = no mask at all).
	uniform float uMaskDark;
	uniform float uMaskLight;
	uniform float uMask;

	// Corner darkening, from 0.0 (none) to 1.0 (black corners).
	uniform float uVignette;

	vec2 emulatedResolution()
	{
		return max(openfl_TextureSize * max(uResolutionScale, 0.0), vec2(1.0));
	}

	// sRGB to linear, clamped so pow() never sees a negative base.
	float toLinear1(float c)
	{
		c = clamp(c, 0.0, 1.0);
		return (c <= 0.04045) ? (c / 12.92) : pow((c + 0.055) / 1.055, 2.4);
	}

	vec3 toLinear(vec3 c)
	{
		return vec3(toLinear1(c.r), toLinear1(c.g), toLinear1(c.b));
	}

	// Linear to sRGB, clamped for the same reason.
	float toSrgb1(float c)
	{
		c = clamp(c, 0.0, 1.0);
		return (c < 0.0031308) ? (c * 12.92) : (1.055 * pow(c, 1.0 / 2.4) - 0.055);
	}

	vec3 toSrgb(vec3 c)
	{
		return vec3(toSrgb1(c.r), toSrgb1(c.g), toSrgb1(c.b));
	}

	// Nearest emulated sample: premultiplied, in linear light, and fully
	// transparent once the warp pushes the coordinate off screen.
	vec4 fetch(vec2 pos, vec2 off)
	{
		vec2 res = emulatedResolution();
		vec2 texel = floor(pos * res + off) / res;
		if (max(abs(texel.x - 0.5), abs(texel.y - 0.5)) > 0.5)
			return vec4(0.0);

		vec4 color = flixel_texture2D(bitmap, texel);
		return vec4(toLinear(color.rgb) * color.a, color.a);
	}

	// Distance in emulated pixels to the nearest texel centre.
	vec2 dist(vec2 pos)
	{
		vec2 scaled = pos * emulatedResolution();
		return -((scaled - floor(scaled)) - vec2(0.5));
	}

	// 1D Gaussian; `scale` is negative, so this is a bell curve.
	float gaus(float pos, float scale)
	{
		return exp2(scale * pos * pos);
	}

	// Scanline weight for the line `off` rows away.
	float scan(vec2 pos, float off)
	{
		return gaus(dist(pos).y + off, uHardScan);
	}

	// 3-tap Gaussian filter along a horizontal line.
	vec4 horz3(vec2 pos, float off)
	{
		vec4 b = fetch(pos, vec2(-1.0, off));
		vec4 c = fetch(pos, vec2(0.0, off));
		vec4 d = fetch(pos, vec2(1.0, off));
		float dst = dist(pos).x;
		float wb = gaus(dst - 1.0, uHardPix);
		float wc = gaus(dst, uHardPix);
		float wd = gaus(dst + 1.0, uHardPix);
		return (b * wb + c * wc + d * wd) / (wb + wc + wd);
	}

	// 5-tap Gaussian filter along a horizontal line.
	vec4 horz5(vec2 pos, float off)
	{
		vec4 a = fetch(pos, vec2(-2.0, off));
		vec4 b = fetch(pos, vec2(-1.0, off));
		vec4 c = fetch(pos, vec2(0.0, off));
		vec4 d = fetch(pos, vec2(1.0, off));
		vec4 e = fetch(pos, vec2(2.0, off));
		float dst = dist(pos).x;
		float wa = gaus(dst - 2.0, uHardPix);
		float wb = gaus(dst - 1.0, uHardPix);
		float wc = gaus(dst, uHardPix);
		float wd = gaus(dst + 1.0, uHardPix);
		float we = gaus(dst + 2.0, uHardPix);
		return (a * wa + b * wb + c * wc + d * wd + e * we) / (wa + wb + wc + wd + we);
	}

	// Let the nearest three scanlines reach this pixel.
	vec4 tri(vec2 pos)
	{
		vec4 a = horz3(pos, -1.0);
		vec4 b = horz5(pos, 0.0);
		vec4 c = horz3(pos, 1.0);
		return a * scan(pos, -1.0) + b * scan(pos, 0.0) + c * scan(pos, 1.0);
	}

	// Curved screen: bulges the middle of each axis outwards.
	vec2 warp(vec2 pos)
	{
		pos = pos * 2.0 - 1.0;
		pos *= vec2(1.0 + (pos.y * pos.y) * uWarp.x, 1.0 + (pos.x * pos.x) * uWarp.y);
		return pos * 0.5 + 0.5;
	}

	// RGB shadow mask: stripes along x, slanted by the scanline they sit on.
	vec3 shadowMask(vec2 pos)
	{
		pos.x += pos.y * 3.0;
		vec3 maskColor = vec3(uMaskDark);
		float stripe = fract(pos.x / 6.0);
		if (stripe < 0.333)
			maskColor.r = uMaskLight;
		else if (stripe < 0.666)
			maskColor.g = uMaskLight;
		else
			maskColor.b = uMaskLight;
		return maskColor;
	}

	void main()
	{
		vec2 uv = warp(openfl_TextureCoordv);
		vec4 accumulated = tri(uv);

		// Un-premultiply: the taps were accumulated premultiplied so that
		// transparent neighbours do not bleed their RGB into the filter. With
		// alpha 0 the accumulated RGB is 0 too, so the guarded divide is exact
		// and stays branch-free.
		float alpha = clamp(accumulated.a, 0.0, 1.0);
		vec3 rgb = accumulated.rgb / max(alpha, 0.0001);

		rgb = toSrgb(rgb);
		rgb *= mix(vec3(1.0), shadowMask(openfl_TextureCoordv * openfl_TextureSize), clamp(uMask, 0.0, 1.0));

		// Vignette: 0.0 at the centre of the screen, 1.0 in the corners.
		vec2 fromCenter = (openfl_TextureCoordv - 0.5) * 2.0;
		float corner = clamp(dot(fromCenter, fromCenter) * 0.5, 0.0, 1.0);
		rgb *= 1.0 - clamp(uVignette, 0.0, 1.0) * corner;

		gl_FragColor = vec4(rgb, alpha);
	}
	')

  public function new()
  {
    super();
    uResolutionScale.value = [0.5];
    uHardScan.value = [-8.0];
    uHardPix.value = [-2.0];
    uWarp.value = [1.0 / 32.0, 1.0 / 24.0];
    uMaskDark.value = [0.5];
    uMaskLight.value = [1.5];
    uMask.value = [1.0];
    uVignette.value = [0.25];
  }
}
