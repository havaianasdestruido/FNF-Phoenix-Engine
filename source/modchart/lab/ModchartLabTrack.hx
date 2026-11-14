package modchart.lab;

import modchart.PercentStore;
import modchart.lab.LabKeyframe;

/**
 * Automation for one percent of one modifier on one side — the lab's unit of
 * work.
 *
 * Beats are stored **loop-local** (`0 ... section length`), so changing the
 * section start only shifts the generated `modEase` calls instead of
 * invalidating the shape, and the same track can be exported as a loop.
 *
 * `valueAt` mirrors what the exporter writes (`modSet` at the section start,
 * then one `modEase` per segment, easing into each keyframe), so the preview
 * and the copied script describe the same motion.
 */
class ModchartLabTrack
{
	/** Beats closer than this are treated as the same keyframe. */
	public static inline final SAME_BEAT:Float = 0.001;

	/** Registry name of the modifier this percent belongs to (`drunk`). */
	public var modifier:String;

	/** Percent name, script spelling (`drunkX`). */
	public var percent:String;

	/** `0` = opponent, `1` = player, `-1` = both sides. */
	public var player:Int;

	/** Recorded keyframes, always sorted by beat. */
	public var keys:Array<LabKeyframe> = [];

	/**
	 * @param modifier Registry name of the modifier.
	 * @param percent Percent name, script spelling.
	 * @param player Side the track drives (`-1` = both).
	 */
	public function new(modifier:String, percent:String, player:Int = -1)
	{
		this.modifier = modifier;
		this.percent = percent;
		this.player = player;
	}

	/**
	 * True when nothing has been recorded yet.
	 *
	 * @return Whether the track has no keyframes.
	 */
	public function isEmpty():Bool
	{
		return keys.length == 0;
	}

	/**
	 * Number of recorded keyframes.
	 *
	 * @return The keyframe count.
	 */
	public function count():Int
	{
		return keys.length;
	}

	/**
	 * Records a value at `beat`.
	 *
	 * The lab calls this every frame while a slider is dragged, so the same
	 * beat bucket keeps being rewritten instead of piling up duplicate
	 * keyframes: a key within `spacing` of the last one is updated in place,
	 * otherwise a new key is inserted in beat order.
	 *
	 * @param beat Loop-local beat.
	 * @param value Percent value at that beat.
	 * @param spacing Minimum distance, in beats, before a new key is appended (`0` disables it).
	 * @return `true` when the track changed.
	 */
	public function record(beat:Float, value:Float, spacing:Float = 0):Bool
	{
		if (!Math.isFinite(beat) || !Math.isFinite(value))
			return false;

		var index:Int = 0;
		while (index < keys.length && keys[index].beat < beat - SAME_BEAT)
			index++;

		if (index < keys.length && Math.abs(keys[index].beat - beat) <= SAME_BEAT)
		{
			if (keys[index].value == value)
				return false;
			keys[index].value = value;
			return true;
		}
		if (index > 0 && spacing > 0 && beat - keys[index - 1].beat < spacing)
		{
			// Same bucket as the previous key: keep its beat, take the new value.
			if (keys[index - 1].value == value)
				return false;
			keys[index - 1].value = value;
			return true;
		}
		keys.insert(index, {beat: beat, value: value});
		return true;
	}

	/**
	 * Value of the automation at `beat`.
	 *
	 * Before the first key the first value is held and after the last key the
	 * last value is held, matching the exported `modSet` + final `modEase`.
	 *
	 * @param beat Loop-local beat.
	 * @param ease Easing used inside a segment (`null` = linear).
	 * @param fallback Value returned when nothing has been recorded.
	 * @return The interpolated percent.
	 */
	public function valueAt(beat:Float, ease:Float->Float, fallback:Float = 0):Float
	{
		if (keys.length == 0)
			return fallback;
		if (beat <= keys[0].beat)
			return keys[0].value;
		final last:LabKeyframe = keys[keys.length - 1];
		if (beat >= last.beat)
			return last.value;

		var index:Int = 1;
		while (index < keys.length && keys[index].beat < beat)
			index++;
		final to:LabKeyframe = keys[index];
		final from:LabKeyframe = keys[index - 1];
		final span:Float = to.beat - from.beat;
		if (span <= 0)
			return to.value;
		final t:Float = (beat - from.beat) / span;
		return from.value + (to.value - from.value) * (ease == null ? t : ease(t));
	}

	/**
	 * Lowest recorded value.
	 *
	 * @return The minimum, or `0` when the track is empty.
	 */
	public function minValue():Float
	{
		var value:Float = keys.length == 0 ? 0 : keys[0].value;
		for (key in keys)
			value = Math.min(value, key.value);
		return value;
	}

	/**
	 * Highest recorded value.
	 *
	 * @return The maximum, or `0` when the track is empty.
	 */
	public function maxValue():Float
	{
		var value:Float = keys.length == 0 ? 0 : keys[0].value;
		for (key in keys)
			value = Math.max(value, key.value);
		return value;
	}

	/**
	 * Drops every keyframe past `length` beats, used when the section shrinks.
	 *
	 * @param length Section length in beats.
	 * @return Number of keyframes removed.
	 */
	public function clip(length:Float):Int
	{
		var removed:Int = 0;
		while (keys.length > 0 && keys[keys.length - 1].beat > length + SAME_BEAT)
		{
			keys.pop();
			removed++;
		}
		return removed;
	}

	/**
	 * Sorted copy of the keyframes, for the exporter and the ruler.
	 *
	 * @return A new array; mutating it leaves the track untouched.
	 */
	public function snapshot():Array<LabKeyframe>
	{
		final out:Array<LabKeyframe> = [];
		for (key in keys)
			out.push({beat: key.beat, value: key.value});
		return out;
	}

	/** Empties the automation. */
	public function clear():Void
	{
		keys = [];
	}

	/**
	 * True when this track is the automation for a given percent/side.
	 *
	 * @param modifier Registry name.
	 * @param percent Percent name, case-insensitive.
	 * @param player Side (`-1` = both).
	 * @return Whether the track matches.
	 */
	public function matches(modifier:String, percent:String, player:Int):Bool
	{
		return PercentStore.normalize(this.modifier) == PercentStore.normalize(modifier)
			&& PercentStore.normalize(this.percent) == PercentStore.normalize(percent)
			&& this.player == player;
	}
}
