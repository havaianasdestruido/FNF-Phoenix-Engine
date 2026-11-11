package play.helpers;

import backend.ClientPrefs;
import backend.Conductor;
import modchart.ModchartManager;
import modchart.ModchartOutput;
import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.PlayField;
import objects.Note;
import objects.StrumNote;
import play.PlayState;

@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateModchart
{
	static var defaults:haxe.ds.ObjectMap<StrumNote, StrumDefault> = new haxe.ds.ObjectMap();
	static var wasActive:Bool = false;
	static var params:ModchartParams = new ModchartParams();
	static var output:ModchartOutput = new ModchartOutput();
	static var basePos:ModchartVec3 = new ModchartVec3();

	static function getManager(state:PlayState):ModchartManager
	{
		return state.modchart;
	}

	/** Creates the manager. Called from `PlayState.create` before scripts run. */
	public static function setup(state:PlayState):Void
	{
		if (state.modchart == null)
			state.modchart = new ModchartManager();
		defaults = new haxe.ds.ObjectMap();
		wasActive = false;
		syncPlayfield(state);
		captureDefaults(state);
	}

	public static function isActive(state:PlayState):Bool
	{
		final manager:ModchartManager = getManager(state);
		return manager != null && manager.isActive();
	}

	static function syncPlayfield(state:PlayState):Void
	{
		final manager:ModchartManager = getManager(state);
		if (manager == null)
			return;
		for (field in manager.playfields)
		{
			field.screenWidth = FlxG.width;
			field.screenHeight = FlxG.height;
			field.scrollSpeed = 0.45 * state.songSpeed;
			field.crochet = Conductor.crochet;
			field.downscroll = ClientPrefs.downScroll;
			// Derived from the live groups so custom-noted (5K+) charts keep
			// their layout; falls back to 4K before the strums exist.
			final keyCount:Int = (state.playerStrums != null && state.playerStrums.members.length > 0) ? state.playerStrums.members.length : 4;
			field.keyCount = keyCount;
			// Filled in place: sync runs every active frame.
			for (player in 0...2)
			{
				field.receptorX[player] = fitLanes(field.receptorX[player], keyCount);
				field.receptorY[player] = fitLanes(field.receptorY[player], keyCount);
			}
			if (state.strumLineNotes != null)
			{
				state.strumLineNotes.forEachAlive(function(strum:StrumNote) {
					final player:Int = strum.player;
					final lane:Int = strum.noteData;
					if (player >= 0 && player < 2 && lane >= 0 && lane < keyCount)
					{
						field.receptorX[player][lane] = strum.x;
						field.receptorY[player][lane] = strum.y;
					}
				});
			}
		}
	}

	/** Grows/shrinks a receptor lane array only when the chart's key count changes. */
	static function fitLanes(lanes:Array<Float>, keyCount:Int):Array<Float>
	{
		if (lanes == null)
			return [for (_ in 0...keyCount) 0.0];
		if (lanes.length == keyCount)
			return lanes;
		while (lanes.length < keyCount)
			lanes.push(0);
		while (lanes.length > keyCount)
			lanes.pop();
		return lanes;
	}

	static function captureDefaults(state:PlayState):Void
	{
		if (state.strumLineNotes == null)
			return;
		state.strumLineNotes.forEachAlive(function(strum:StrumNote) {
			writeDefault(strum, strum.x, strum.y);
		});
	}

	/** Writes the current live values into the cached default, allocating only the first time. */
	static function writeDefault(strum:StrumNote, x:Float, y:Float):StrumDefault
	{
		var base:StrumDefault = defaults.get(strum);
		if (base == null)
		{
			base = {
				x: x,
				y: y,
				angle: strum.angle,
				scaleX: strum.scale.x,
				scaleY: strum.scale.y,
				alpha: strum.alpha,
				writtenAngle: 0,
				writtenScaleX: 1,
				writtenScaleY: 1,
				writtenAlpha: 1
			};
			defaults.set(strum, base);
			return base;
		}
		base.x = x;
		base.y = y;
		base.angle = strum.angle;
		base.scaleX = strum.scale.x;
		base.scaleY = strum.scale.y;
		base.alpha = strum.alpha;
		base.writtenAngle = 0;
		base.writtenScaleX = 1;
		base.writtenScaleY = 1;
		base.writtenAlpha = 1;
		return base;
	}

	static function restoreStrums(state:PlayState):Void
	{
		if (state.strumLineNotes == null)
			return;
		state.strumLineNotes.forEachAlive(function(strum:StrumNote) {
			final base:StrumDefault = defaults.get(strum);
			if (base == null)
				return;
			strum.x = base.x;
			strum.y = base.y;
			strum.angle = base.angle;
			strum.scale.set(base.scaleX, base.scaleY);
			strum.alpha = base.alpha;
			base.writtenAngle = 0;
			base.writtenScaleX = 1;
			base.writtenScaleY = 1;
			base.writtenAlpha = 1;
		});
	}

	/** Keeps captured receptor positions in step with window resizes. */
	public static function shiftDefaults(state:PlayState, shift:Float):Void
	{
		if (shift == 0)
			return;
		for (base in defaults)
			base.x += shift;
	}

	/**
	 * Advances the event timeline and transforms receptors. Must run before
	 * `Note.followStrum` so notes inherit the moved strums. When the
	 * modchart is inactive this only tracks the strums' live values (so the
	 * intro alpha tween is not frozen) and costs one null check.
	 */
	public static function updateStrums(state:PlayState, elapsed:Float):Void
	{
		final manager:ModchartManager = getManager(state);
		if (manager == null)
			return;
		if (!manager.isActive())
		{
			if (wasActive)
			{
				restoreStrums(state);
				wasActive = false;
			}
			captureDefaults(state);
			return;
		}
		wasActive = true;
		manager.update(state.curDecBeat);
		syncPlayfield(state);
		if (state.strumLineNotes == null)
			return;

		final songTime:Float = Conductor.songPosition;
		final curBeat:Float = state.curDecBeat;
		state.strumLineNotes.forEachAlive(function(strum:StrumNote) {
			var base:StrumDefault = defaults.get(strum);
			if (base == null)
				base = writeDefault(strum, strum.x, strum.y);
			params.songTime = songTime;
			params.curBeat = curBeat;
			params.hitTime = songTime;
			params.distance = 0;
			params.lane = strum.noteData;
			params.player = strum.player;
			params.isTapArrow = false;
			params.isReceptor = true;
			// Recover the resting values by removing what the modchart wrote last
			// frame: the intro alpha tween and script setProperty calls then keep
			// working instead of fighting the runtime.
			base.angle = strum.angle - base.writtenAngle;
			base.scaleX = strum.scale.x / base.writtenScaleX;
			base.scaleY = strum.scale.y / base.writtenScaleY;
			if (base.writtenAlpha != 0)
				base.alpha = strum.alpha / base.writtenAlpha;
			params.receptorX = base.x;
			params.receptorY = base.y;
			basePos.set(base.x, base.y, 0);
			applyFields(manager, basePos, params);
			strum.x = output.pos.x;
			strum.y = output.pos.y;
			strum.angle = base.angle + output.visuals.angleZ;
			strum.scale.set(base.scaleX * output.visuals.scaleX, base.scaleY * output.visuals.scaleY);
			strum.alpha = base.alpha * output.visuals.alpha;
			base.writtenAngle = output.visuals.angleZ;
			base.writtenScaleX = output.visuals.scaleX;
			base.writtenScaleY = output.visuals.scaleY;
			base.writtenAlpha = output.visuals.alpha;
		});
	}

	/**
	 * Transforms live notes after `followStrum` has positioned them.
	 * Angle/alpha/scale are multiplicative on the values `followStrum` just
	 * wrote, so pooled/recycled notes need no per-note default storage.
	 * Sustain `scaleY` is left alone (it encodes hold length).
	 */
	public static function updateNotes(state:PlayState):Void
	{
		final manager:ModchartManager = getManager(state);
		if (manager == null || !manager.isActive())
			return;
		syncPlayfield(state);
		final songTime:Float = Conductor.songPosition;
		final curBeat:Float = state.curDecBeat;
		for (group in [state.notes, state.sustainNotes])
		{
			if (group == null)
				continue;
			group.forEachAlive(function(note:Note) {
				final strums = note.mustPress ? state.playerStrums : state.opponentStrums;
				if (strums == null || note.noteData < 0 || note.noteData >= strums.members.length)
					return;
				final strum:StrumNote = strums.members[note.noteData];
				if (strum == null)
					return;
				params.songTime = songTime;
				params.curBeat = curBeat;
				params.hitTime = note.strumTime;
				params.distance = (note.strumTime - songTime) * 0.45 * state.songSpeed * note.multSpeed;
				params.lane = note.noteData;
				params.player = strum.player;
				params.isTapArrow = !note.isSustainNote;
				params.isReceptor = false;
				params.receptorX = strum.x;
				params.receptorY = strum.y;
				basePos.set(note.x, note.y, 0);
				applyFields(manager, basePos, params);
				// Only touch fields `followStrum` rewrites this frame: anything
				// else would accumulate across updates instead of replacing.
				if (note.copyX)
					note.x = output.pos.x;
				if (note.copyY)
					note.y = output.pos.y;
				if (note.copyAngle)
					note.angle += output.visuals.angleZ;
				if (note.copyAlpha)
					note.alpha *= output.visuals.alpha;
				if (note.copyScaleX)
					note.scale.x *= output.visuals.scaleX;
				if (note.copyScaleY && !note.isSustainNote)
					note.scale.y *= output.visuals.scaleY;
			});
		}
	}

	static function applyFields(manager:ModchartManager, pos:ModchartVec3, params:ModchartParams):Void
	{
		output.pos.copyFrom(pos);
		output.visuals.reset();
		for (field in manager.playfields)
		{
			final result:ModchartOutput = field.transform(output.pos, params, output);
			output.pos.copyFrom(result.pos);
		}
	}

	/** Restores receptors and drops the manager. Called from `PlayState.destroy`. */
	public static function reset(state:PlayState):Void
	{
		if (state.modchart != null)
		{
			restoreStrums(state);
			state.modchart.clear();
		}
		defaults = new haxe.ds.ObjectMap();
		wasActive = false;
	}
}

typedef StrumDefault =
{
	var x:Float;
	var y:Float;
	var angle:Float;
	var scaleX:Float;
	var scaleY:Float;
	var alpha:Float;
	// Visuals written by the last frame, so external changes can be separated
	// from the modchart's own output (see updateStrums).
	var writtenAngle:Float;
	var writtenScaleX:Float;
	var writtenScaleY:Float;
	var writtenAlpha:Float;
}
