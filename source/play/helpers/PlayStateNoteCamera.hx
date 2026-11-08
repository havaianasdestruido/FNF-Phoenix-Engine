package play.helpers;

import backend.ClientPrefs;
import play.PlayState;
import shaders.DistantNoteShader;
import shaders.DistantNoteWarp;

#if SHADERS_ALLOWED
import openfl.filters.ShaderFilter;
#end

/**
 * Owns `PlayState.camStrum`: the camera that draws the strums and notes, and the
 * Distant Note effect on it.
 *
 * ### Why a separate camera
 *
 * The Distant Note shader is a filter, and a filter is applied to everything a
 * camera draws. Warping `camHUD` would warp the health bar, the score and the
 * time bar too, so the notes get their own camera instead: `camHUD` keeps the
 * HUD and `camStrum` draws only the lane. Both are resized and zoomed with the
 * HUD (`syncWithHud`), so the lane stays glued to the rest of the interface when
 * the HUD booms on a beat.
 *
 * ### Requirement: middlescroll
 *
 * The warp is anchored on the middle of the screen, which is where the notes
 * have to be for it to look like a corridor (Doido Engine forces middlescroll
 * for the same reason, see `DistantNoteWarp.requiresMiddleScroll()`). When the
 * player turns the option on with the lanes on the sides, gameplay forces it on
 * for that song instead of drawing a broken perspective, the same way
 * `Middlescroll` and the `bothSides` gameplay changer are resolved today.
 *
 * ### Cost
 *
 * A filter costs a render-to-texture pass, so the effect is only attached while
 * `ClientPrefs.distantNotes` is on and shaders are enabled. With the option off,
 * `camStrum` has no filters and draws the lane exactly like `camHUD` would.
 */
class PlayStateNoteCamera
{
	/**
	 * Whether the current run should warp the lane.
	 *
	 * Shaders off means "no filters anywhere", and so does a build without
	 * shader support: `SHADERS_ALLOWED` is false on Flash/AIR, where the option
	 * is filtered out of the menu anyway.
	 */
	public static function wantsDistantNotes():Bool
	{
		if (!ClientPrefs.distantNotes) return false;
		if (!ClientPrefs.shaders) return false;
		#if SHADERS_ALLOWED
		return true;
		#else
		return false;
		#end
	}

	/**
	 * `true` when the option asks for middlescroll to be forced on.
	 *
	 * Gameplay resolves `PlayState.middleScroll` before the lane is built, so the
	 * warp and the forced centering agree on where the notes are.
	 */
	public static function forcesMiddleScroll():Bool
	{
		return wantsDistantNotes() && DistantNoteWarp.requiresMiddleScroll();
	}

	/**
	 * Creates the lane camera and its filter, if the run wants them.
	 *
	 * @param state The state being created.
	 */
	public static function create(state:PlayState):Void
	{
		if (!wantsDistantNotes()) return;

		#if SHADERS_ALLOWED
		final shader:DistantNoteShader = new DistantNoteShader();
		shader.uDownscroll.value = [ClientPrefs.downScroll];
		state.distantNoteShader = shader;
		state.camStrum.filters = [new ShaderFilter(shader)];
		#end
	}

	/**
	 * Re-applies the current preference to a live state.
	 *
	 * Used by the option's `onChange` and by the pause menu, so toggling the
	 * option takes effect without restarting the song.
	 *
	 * @param state The running gameplay state, or `null`.
	 */
	public static function refresh(state:PlayState):Void
	{
		if (state == null || state.camStrum == null) return;

		#if SHADERS_ALLOWED
		if (!wantsDistantNotes())
		{
			state.camStrum.filters = null;
			state.distantNoteShader = null;
			return;
		}

		if (state.distantNoteShader == null) state.distantNoteShader = new DistantNoteShader();

		state.distantNoteShader.uDownscroll.value = [ClientPrefs.downScroll];
		state.camStrum.filters = [new ShaderFilter(state.distantNoteShader)];
		#end
	}

	/**
	 * Keeps `camStrum` in step with the HUD camera.
	 *
	 * The lane camera draws the same coordinates `camHUD` does, so it copies the
	 * HUD's zoom, angle and alpha every frame; otherwise the HUD's beat zoom and
	 * the `twist` event would move the HUD but leave the notes behind.
	 *
	 * Only the fields a second camera can observe are copied. The screen shake
	 * lives inside `flixel.FlxCamera`'s private sprite, so a shake of the HUD
	 * moves the HUD alone; a stage that wants the lane to shake too shakes both
	 * cameras (see `PlayStateNoteCamera.shake`).
	 *
	 * @param state The running gameplay state.
	 */
	public static function syncWithHud(state:PlayState):Void
	{
		final hud:flixel.FlxCamera = state.camHUD;
		final lane:flixel.FlxCamera = state.camStrum;
		if (hud == null || lane == null) return;

		// A stage that hides the HUD (cutscenes, `Mall`, ...) must hide the lane
		// with it, since the lane is no longer part of `camHUD`. A hidden lane
		// camera also skips its filter pass for free.
		lane.visible = hud.visible;
		lane.alpha = hud.alpha;
		lane.angle = hud.angle;
		lane.zoom = hud.zoom;
		lane.x = hud.x;
		lane.y = hud.y;
		lane.scroll.copyFrom(hud.scroll);
	}

	/**
	 * Shakes the HUD and the lane together.
	 *
	 * A stage or script that shakes `camHUD` directly moves only the HUD, because
	 * the lane now draws on its own camera. This helper keeps the two in sync for
	 * the common "shake the whole interface" case; the arguments are the ones
	 * `flixel.FlxCamera.shake` takes.
	 */
	public static function shake(state:PlayState, ?intensity:Float = 0.05, ?duration:Float = 0.5, ?onComplete:Void->Void, ?force:Bool = true):Void
	{
		if (state == null) return;
		if (state.camHUD != null) state.camHUD.shake(intensity, duration, onComplete, force);
		if (state.camStrum != null) state.camStrum.shake(intensity, duration, null, force);
	}
}
