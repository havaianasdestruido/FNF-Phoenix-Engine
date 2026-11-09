package objects;

import flixel.util.FlxColor;
import backend.ClientPrefs;

/**
 * Central helper for resolving note lane colors.
 *
 * `Note` used to duplicate the `ClientPrefs.arrowRGB` / `arrowRGBPixel`
 * ternary in several places (`Note`, `StrumNote`, `NoteHelpers`). This
 * class is the single source of truth so a single call can be reused and
 * mocked in tests. Mirrors Psych Engine / Phoenix Engine's normal lane
 * colors and keeps the pixel-stage variant separate.
 *
 * Usage:
 * ```haxe
 * var colors = NoteColors.laneRGB(noteData, PlayState.isPixelStage);
 * ```
 */
class NoteColors
{
	/**
	 * Returns the 3-color RGB array for a given lane.
	 *
	 * @param noteData     lane index, 0 = left, 3 = right. For mania >4 the
	 *                     caller should already have bounds-checked; out-of-range
	 *                     returns `null` so `defaultRGB()` can safely skip.
	 * @param isPixelStage whether the current stage is a pixel stage
	 *                     (`PlayState.isPixelStage`). When true, the pixel
	 *                     palette `arrowRGBPixel` is used.
	 * @return `Array<FlxColor>` of length 3 `[r, g, b]` or `null` if the lane
	 *         is invalid.
	 */
	public static inline function laneRGB(noteData:Int, isPixelStage:Bool):Array<FlxColor>
	{
		var table:Array<Array<FlxColor>> = isPixelStage ? ClientPrefs.arrowRGBPixel : ClientPrefs.arrowRGB;
		if (table == null) return null;
		if (noteData < 0 || noteData >= table.length) return null;
		return table[noteData];
	}

	/**
	 * Alias kept for callers that prefer an explicit name.
	 */
	public static inline function getLaneRGB(noteData:Int, isPixelStage:Bool):Array<FlxColor>
	{
		return laneRGB(noteData, isPixelStage);
	}

	/**
	 * Quant-based colors (`ClientPrefs.quantRGB`) for the quant note style.
	 * Not used by `Note.defaultRGB()` but provided for `NotesSubState` and
	 * future note types that need a quant index instead of a lane.
	 */
	public static inline function quantRGB(quantIndex:Int):Array<FlxColor>
	{
		var table = ClientPrefs.quantRGB;
		if (table == null) return null;
		if (quantIndex < 0 || quantIndex >= table.length) return null;
		return table[quantIndex];
	}
}
