package shaders;

import backend.FlxFixedShader;

/**
 * Broken old television: a rolling picture-offset bar that drags its rows
 * sideways, an optional smear, black and white sploches, and analogue static
 * mixed over the whole image.
 *
 * Ported from Mario Madness' `OldTVShader`:
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/OldTVShader.hx
 *
 * Differences from the port source, all of them deliberate:
 * - the hash is float based (Dave Hoskins' `hash12`/`hash13` pattern) instead of
 *   `uvec3` with unsigned literals: `uvec` and the `U` suffix do not exist in
 *   GLSL ES 1.00, which is what the HTML5/WebGL build compiles;
 * - the tuning constants the upstream hardcoded are uniforms (`uBarOffset`,
 *   `uBlur`, `uStatic`, `uDamage`) so a mod can dial the damage down instead of
 *   having to fork the shader;
 * - the smear is 8 directions x 2 taps (16 fetches) behind a `uBlur > 0.0`
 *   branch instead of an unconditional 16 x 3 (48 fetches), and defaults to off
 *   because it is the single most expensive part of the effect;
 * - the blur loop uses an `int` counter with constant bounds, the loops GLSL ES
 *   1.00 allows, instead of a float counter stepping by a variable;
 * - every literal is a float literal, and the output keeps the sampled alpha
 *   instead of writing 1.0, so the effect can sit on `camHUD` without turning
 *   the HUD opaque.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 *
 * Animated: `shaders.OldTVEffect` advances `uTime` every frame.
 */
class OldTVShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// Seconds since the effect started; drives every animated term.
	uniform float uTime;

	// Rolling picture-offset bar: a band that travels down the screen and
	// drags its rows sideways.
	uniform bool uBar;

	// How far the bar displaces its rows, in UV units (0.01 upstream).
	uniform float uBarOffset;

	// Smear radius in render-target pixels. 0.0 skips the blur loop entirely.
	uniform float uBlur;

	// How much analogue static is mixed over the picture (0.05 upstream).
	uniform float uStatic;

	// Overall damage, 0.0 (a clean picture with static only) to 1.0 (upstream).
	uniform float uDamage;

	// Cheap float hashes: no unsigned integers, so they also compile on
	// GLSL ES 1.00 / WebGL1.
	float hash12(vec2 p)
	{
		vec3 p3 = fract(vec3(p.xyx) * 0.1031);
		p3 += dot(p3, p3.yzx + 33.33);
		return fract((p3.x + p3.y) * p3.z);
	}

	float hash13(vec3 p)
	{
		p = fract(p * 0.1031);
		p += dot(p, p.zyx + 31.32);
		return fract((p.x + p.y) * p.z);
	}

	void main()
	{
		vec2 uv = openfl_TextureCoordv;
		vec2 texSize = max(openfl_TextureSize, vec2(1.0));
		float damage = clamp(uDamage, 0.0, 1.0);

		// `damaged` rows may grow white specks; `blacked` rows are already
		// crushed to black and must not get static on top.
		bool damaged = false;
		bool blacked = false;

		// Rolling bar: a 50 pixel tall band, plus a second band 1.25s behind it,
		// both scrolling once every 2.5 seconds.
		if (uBar && damage > 0.0)
		{
			float bandHalf = 25.0 / texSize.y;
			float row = hash13(vec3(0.0, uv.y * 100.0, uTime * 50.0)) * uBarOffset * damage;
			float first = mod(uTime, 2.5) * 0.5;
			if (abs(uv.y - first) <= bandHalf)
			{
				uv.x -= row;
				damaged = true;
			}
			else if (uTime > 1.25 && abs(uv.y - mod(uTime - 1.25, 2.5) * 0.5) <= bandHalf)
			{
				uv.x -= row;
				damaged = true;
			}
		}

		vec4 col = flixel_texture2D(bitmap, uv);
		float alpha = col.a;

		// Optional smear: 8 directions x 2 distances plus the centre sample.
		if (uBlur > 0.0)
		{
			vec2 radius = uBlur / texSize;
			vec3 sum = col.rgb;
			for (int d = 0; d < 8; d++)
			{
				float angle = float(d) * 0.7853981634;
				vec2 direction = vec2(cos(angle), sin(angle)) * radius;
				for (int tap = 1; tap <= 2; tap++)
					sum += flixel_texture2D(bitmap, uv + direction * (float(tap) * 0.5)).rgb;
			}
			col.rgb = sum / 17.0;
		}

		// Picture dragged off the left edge: black.
		if (uv.x < 0.0)
		{
			col.rgb = vec3(0.0);
			damaged = false;
			blacked = true;
		}

		// Random black sploches creeping in from the left of a few rows.
		float cutoff = 1.0 - 0.08 * damage;
		float rowNoise = hash13(vec3(uv.y * 100.0, 0.0, uTime * 100.0));
		if (damage > 0.0 && rowNoise > cutoff)
		{
			float width = (rowNoise - cutoff) / max(1.0 - cutoff, 0.0001) * 0.007;
			if (uv.x < width)
			{
				col.rgb = vec3(0.0);
				blacked = true;
			}
			else
			{
				damaged = true;
			}
		}

		// Analogue static over whatever survived.
		if (!blacked && uStatic > 0.0)
		{
			float noise = hash13(vec3(uv.x * texSize.x, uv.y * texSize.y, uTime * 100.0));
			col.rgb = mix(col.rgb, vec3(noise), clamp(uStatic, 0.0, 1.0));
		}

		// White specks inside the damaged rows.
		if (damaged && damage > 0.0)
		{
			float speckCutoff = 1.0 - 0.05 * damage;
			float val = hash13(vec3(uv.x * 20.0, uv.y * 400.0, uTime * 75.0));
			if (val > speckCutoff)
			{
				float offset = hash13(vec3(uv.y * 400.0, uv.x * 20.0, uTime * 75.0));
				float amount = (val - speckCutoff) / max(1.0 - speckCutoff, 0.0001) * 0.7;
				amount -= abs((uv.x * 20.0 - (floor(uv.x * 20.0) + offset)) * 0.7);
				col.rgb = mix(col.rgb, vec3(1.0), clamp(amount, 0.0, 1.0));
			}
		}

		gl_FragColor = vec4(col.rgb, alpha);
	}
	')

  public function new()
  {
    super();
    uTime.value = [0.0];
    uBar.value = [true];
    uBarOffset.value = [0.01];
    uBlur.value = [0.0];
    uStatic.value = [0.05];
    uDamage.value = [1.0];
  }
}
