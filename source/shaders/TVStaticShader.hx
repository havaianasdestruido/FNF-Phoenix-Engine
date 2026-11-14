package shaders;

import backend.FlxFixedShader;

/**
 * Untuned-television static: a churning noise field subtracted from the picture,
 * pulsing between a floor and a ceiling over time. This is the effect Mario
 * Madness runs on its title screen.
 *
 * Ported from the `TVStatic` class of Mario Madness' `TitleScreenShaders.hx`
 * (by @Ne_Eo_Twitch, modded by lunar):
 * https://github.com/Dewott2501/Mario-Madness/blob/main/source/TitleScreenShaders.hx
 *
 * Differences from the port source, all of them deliberate:
 * - the uniforms are named (`uTime`, `uStrength`, `uMinStrength`, `uMaxStrength`,
 *   `uSpeed`) instead of `strengthMulti` / `imtoolazytonamethis`;
 * - `maxStrength` and `speed` are uniforms too, so a mod can have calm static;
 * - the output keeps the sampled alpha instead of writing 1.0, which is what
 *   lets it sit on a single sprite (the title screen logo or dancer) rather than
 *   only on a full-screen camera;
 * - every literal is a float literal.
 *
 * Extends FlxFixedShader rather than FlxShader so the same GLSL also runs on
 * OpenGL ES (Android/WebGL2), which rewrites the source to GLSL ES 3.00.
 *
 * Animated: `shaders.TVStaticEffect` advances `uTime` every frame.
 */
class TVStaticShader extends FlxFixedShader
{
	@:glFragmentSource('
	#pragma header

	// Seconds since the effect started.
	uniform float uTime;

	// Overall multiplier on the static strength.
	uniform float uStrength;

	// Floor and ceiling of the pulsing strength (0.3 / 0.8 upstream).
	uniform float uMinStrength;
	uniform float uMaxStrength;

	// How fast the noise field churns (20.0 upstream).
	uniform float uSpeed;

	float random(vec2 noise)
	{
		return fract(sin(dot(noise.xy, vec2(10.998, 98.233))) * 12433.14159265359);
	}

	void main()
	{
		vec2 uv = openfl_TextureCoordv;
		vec2 scrolled = fract(uv * fract(sin(uTime * uSpeed)));

		// Pulse between the two strength bounds; a floor above the ceiling just
		// pins the strength to the ceiling.
		float strength = clamp(sin(uTime * 0.5), uMinStrength, max(uMinStrength, uMaxStrength)) * uStrength;

		vec3 colour = vec3(random(scrolled) - 0.1) * strength;
		vec4 background = flixel_texture2D(bitmap, uv);

		gl_FragColor = vec4(background.rgb - colour, background.a);
	}
	')

  public function new()
  {
    super();
    uTime.value = [0.0];
    uStrength.value = [1.0];
    uMinStrength.value = [0.3];
    uMaxStrength.value = [0.8];
    uSpeed.value = [20.0];
  }
}
