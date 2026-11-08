package shaders;

import flixel.system.FlxAssets.FlxShader;

/**
 * Perspective ("distance") warp for the notes, ported from Doido Engine's
 * `DistantNoteShader`:
 * <https://github.com/DoidoTeam/FNF-Doido-Engine/blob/main/source/backend/shaders/DistantNoteShader.hx>
 *
 * The shader samples the camera texture with a horizontal offset that grows with
 * the vertical distance from a *horizon line*, which makes the two note lanes
 * look like they recede into a vanishing point in the middle of the screen
 * instead of standing up flat. A note sitting on the horizon is untouched; the
 * further a note is from it, the more it leans towards the centre.
 *
 * Phoenix applies it to the strum/note camera (`PlayState.camStrum`), so the rest
 * of the HUD keeps its normal perspective: health bar, score, time bar and popups
 * are not warped. Doido instead requires middlescroll because its lanes are
 * already centered; that requirement applies here too, and the gameplay option
 * forces it on when the shader is enabled.
 *
 * The constants and the math live in `shaders.DistantNoteWarp`, which is free of
 * Flixel imports so `tests/haxe/DistantNoteWarpSpec.hx` can check them.
 */
class DistantNoteShader extends FlxShader
{
	/** Horizon line, as a fraction of the texture height. */
	public static inline var HORIZON:Float = DistantNoteWarp.HORIZON;

	/** Cone slope: larger values warp less. */
	public static inline var CONE:Float = DistantNoteWarp.CONE;

	@:glFragmentSource('
		#pragma header

		// 1.0 while the chart scrolls down, 0.0 while it scrolls up. The lane is
		// mirrored vertically in downscroll, so the horizon has to be flipped
		// with it or the notes would lean the wrong way.
		uniform bool uDownscroll;

		// Horizon line, as a fraction of the texture height.
		uniform float uHorizon;

		// Cone slope: the distance from the horizon is divided by this before it
		// becomes a horizontal offset, so larger values warp less.
		uniform float uCone;

		void main()
		{
			vec2 uv = openfl_TextureCoordv.xy;

			// Distance from the horizon, as a fraction of the texture height.
			// Zero on the horizon, positive on the strum side of it.
			float actualY = uv.y;
			if (uDownscroll)
				actualY = (1.0 - uv.y) - uHorizon;
			else
				actualY = uv.y - uHorizon;

			// Horizontal offset: pixels far from the horizon are pulled towards
			// the middle of the screen, which is what reads as depth.
			float offset = (actualY / uCone) * (uv.x - 0.5);

			// Keep the fetch inside the texture. Sampling outside it would pick up
			// the transparent camera clear colour and punch a hole in the playfield.
			vec2 sampleUv = vec2(clamp(uv.x + offset, 0.0, 1.0), uv.y);

			gl_FragColor = flixel_texture2D(bitmap, sampleUv);
		}')
	public function new()
	{
		super();

		// Defaults match `DistantNoteShader.new()` in Doido Engine, so a shader a
		// mod or a stage creates on its own looks the same.
		uDownscroll.value = [false];
		uHorizon.value = [HORIZON];
		uCone.value = [CONE];
	}
}
