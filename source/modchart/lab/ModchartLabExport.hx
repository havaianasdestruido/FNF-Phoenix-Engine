package modchart.lab;

using StringTools;

import modchart.lab.LabKeyframe;

/**
 * Turns recorded lab tracks into a ready-to-paste script fragment.
 *
 * Output is written against the same Lua/Python API the game exposes
 * (`addModifier`, `modSet`, `modEase`, `modRepeater` — see
 * `docs/MODCHART.md`), so what the lab previews is exactly what a script
 * does. Two shapes are supported:
 *
 * - **once**: one `modSet` anchors every track at the section start, then one
 *   `modEase` per recorded segment at absolute song beats.
 * - **loop**: the same calls wrapped in a callback that a `modRepeater`
 *   re-schedules every section, with beats expressed relative to the passed
 *   `beat` argument.
 *
 * Renderer-free on purpose: `tests/haxe/run-modchart-lab.sh` asserts the
 * exact generated text.
 */
class ModchartLabExport
{
	/** Ease names in the spelling the docs use, in cycle order for the editor's ease picker. */
	public static final EASES:Array<String> = [
		'linear',
		'sineIn',
		'sineOut',
		'sineInOut',
		'quadIn',
		'quadOut',
		'quadInOut',
		'cubeIn',
		'cubeOut',
		'cubeInOut',
		'quartIn',
		'quartOut',
		'quartInOut',
		'quintIn',
		'quintOut',
		'quintInOut',
		'expoIn',
		'expoOut',
		'expoInOut',
		'circIn',
		'circOut',
		'circInOut',
		'elasticIn',
		'elasticOut',
		'elasticInOut',
		'backIn',
		'backOut',
		'backInOut',
		'bounceIn',
		'bounceOut',
		'bounceInOut',
		'smoothStepIn',
		'smoothStepOut',
		'smoothStepInOut',
		'smootherStepIn',
		'smootherStepOut',
		'smootherStepInOut'
	];

	static final DEFAULT_CALLBACK:String = 'onModchartLabSection';
	static final PYTHON_INDENT:String = '    ';
	static final LUA_INDENT:String = '\t';
	static final IDENTIFIER:EReg = ~/^[A-Za-z_][A-Za-z0-9_]*$/;

	/**
	 * Generates the script fragment for the recorded tracks.
	 *
	 * @param tracks Recorded automation (loop-local beats); empty or `null` produces an instruction-only comment.
	 * @param options Section, language, ease and loop mode.
	 * @return Script text with `\n` line endings and no trailing newline.
	 */
	public static function generate(tracks:Array<ModchartLabTrack>, options:ModchartLabExportOptions):String
	{
		final opts:ModchartLabExportOptions = options == null ? new ModchartLabExportOptions() : options;
		final python:Bool = opts.language == Python;
		final comment:String = python ? '#' : '--';
		final indent:String = python ? PYTHON_INDENT : LUA_INDENT;
		final ease:String = canonicalEase(opts.ease);
		final length:Float = opts.length > 0 ? opts.length : 1;
		final start:Float = Math.max(0, opts.startBeat);
		final callback:String = identifier(opts.callbackName, DEFAULT_CALLBACK);
		final usable:Array<ModchartLabTrack> = usableTracks(tracks, length);

		final lines:Array<String> = [];
		lines.push(comment + ' Modchart Lab - Phoenix Engine');
		if (opts.loop)
			lines.push(comment + ' Looping section: ' + number(length) + ' beats from beat ' + number(start) + ', ease ' + ease);
		else
			lines.push(comment + ' Section: beats ' + number(start) + ' -> ' + number(start + length) + ' (' + number(length) + ' beats), ease ' + ease);

		if (usable.length == 0)
		{
			lines.push(comment + ' Nothing recorded yet: pick a modifier, drag a percent, then copy again.');
			return lines.join('\n');
		}
		lines.push(comment + ' Paste into a ' + (python ? 'Python' : 'Lua') + ' script; merge the bodies if you already have these callbacks.');

		final setup:Array<String> = [];
		for (name in modifierNames(usable))
			setup.push('addModifier(' + quote(name) + ')');

		final events:Array<String> = [];
		for (track in usable)
		{
			final block:Array<String> = trackLines(track, start, ease, opts.loop);
			if (block.length == 0)
				continue;
			if (events.length > 0)
				events.push('');
			for (line in block)
				events.push(line);
		}

		lines.push('');
		if (opts.loop)
		{
			final setupBody:Array<String> = setup.copy();
			setupBody.push('');
			setupBody.push('modRepeater(' + number(start) + ', ' + number(length) + ', ' + quote(callback) + ')');
			for (line in functionLines('onCreatePost', [], setupBody, python, indent))
				lines.push(line);
			lines.push('');
			for (line in functionLines(callback, ['beat'], events, python, indent))
				lines.push(line);
		}
		else
		{
			final body:Array<String> = setup.copy();
			body.push('');
			for (line in events)
				body.push(line);
			for (line in functionLines('onCreatePost', [], body, python, indent))
				lines.push(line);
		}
		return lines.join('\n');
	}

	/**
	 * Canonical spelling of an ease name.
	 *
	 * @param name Any case/whitespace variant scripts accept.
	 * @return The documented spelling, or `linear` for an unknown name (same fallback as the runtime).
	 */
	public static function canonicalEase(name:String):String
	{
		if (name == null)
			return 'linear';
		final key:String = name.trim().toLowerCase();
		for (ease in EASES)
		{
			if (ease.toLowerCase() == key)
				return ease;
		}
		return 'linear';
	}

	/**
	 * Steps through the ease picker.
	 *
	 * @param current Current ease name.
	 * @param step `1` for next, `-1` for previous.
	 * @return The neighbouring ease name, wrapping at both ends.
	 */
	public static function nextEase(current:String, step:Int = 1):String
	{
		final index:Int = EASES.indexOf(canonicalEase(current));
		var next:Int = (index + step) % EASES.length;
		if (next < 0)
			next += EASES.length;
		return EASES[next];
	}

	/**
	 * Keeps a generated callback name usable as a script identifier.
	 *
	 * @param name Candidate name.
	 * @param fallback Name used when `name` is empty or not a valid identifier.
	 * @return A valid identifier.
	 */
	public static function identifier(name:String, fallback:String):String
	{
		if (name == null)
			return fallback;
		final trimmed:String = name.trim();
		return IDENTIFIER.match(trimmed) ? trimmed : fallback;
	}

	/**
	 * Formats a number for generated code without float noise.
	 *
	 * @param value Any float.
	 * @return `0`, an integer, or at most three decimals — never `NaN`/`Infinity`.
	 */
	public static function number(value:Float):String
	{
		if (!Math.isFinite(value))
			return '0';
		final rounded:Float = Math.round(value * 1000) / 1000;
		if (rounded == 0)
			return '0';
		if (rounded == Math.ffloor(rounded) && Math.abs(rounded) < 1e9)
			return Std.string(Std.int(rounded));
		return Std.string(rounded);
	}

	/**
	 * Escapes a string for single-quoted Lua/Python literals.
	 *
	 * @param value Raw value.
	 * @return The quoted literal.
	 */
	public static function quote(value:String):String
	{
		final text:String = value == null ? '' : value;
		return "'" + text.replace('\\', '\\\\').replace("'", "\\'") + "'";
	}

	/** `modSet` + `modEase` lines for one track. */
	static function trackLines(track:ModchartLabTrack, start:Float, ease:String, loop:Bool):Array<String>
	{
		final out:Array<String> = [];
		if (track.keys.length == 0)
			return out;

		// Anchor the section at the first recorded value: the preview holds it
		// before the first key, so the script does too.
		out.push('modSet(' + joinArgs([quote(track.percent), beatAt(0, start, loop), number(track.keys[0].value)], track.player) + ')');

		for (i in 1...track.keys.length)
		{
			final from:LabKeyframe = track.keys[i - 1];
			final to:LabKeyframe = track.keys[i];
			final span:Float = to.beat - from.beat;
			if (span <= ModchartLabTrack.SAME_BEAT)
			{
				out.push('modSet(' + joinArgs([quote(track.percent), beatAt(to.beat, start, loop), number(to.value)], track.player) + ')');
				continue;
			}
			out.push('modEase(' + joinArgs([
				quote(track.percent),
				beatAt(from.beat, start, loop),
				number(span),
				number(to.value),
				quote(ease)
			], track.player) + ')');
		}
		return out;
	}

	/** Beat argument for a loop-local beat. */
	static function beatAt(localBeat:Float, start:Float, loop:Bool):String
	{
		if (loop)
			return Math.abs(localBeat) <= ModchartLabTrack.SAME_BEAT ? 'beat' : 'beat + ' + number(localBeat);
		return number(start + localBeat);
	}

	/** Appends the optional `player` argument when the track is side-specific. */
	static function joinArgs(args:Array<String>, player:Int):String
	{
		final parts:Array<String> = args.copy();
		if (player >= 0)
			parts.push(Std.string(player));
		return parts.join(', ');
	}

	/** Emits `function name(args)` … `end` (Lua) or `def name(args):` … (Python). */
	static function functionLines(name:String, args:Array<String>, body:Array<String>, python:Bool, indent:String):Array<String>
	{
		final out:Array<String> = [];
		final signature:String = name + '(' + args.join(', ') + ')';
		out.push(python ? 'def ' + signature + ':' : 'function ' + signature);
		if (body.length == 0)
			out.push(indent + (python ? 'pass' : '-- nothing to do'));
		for (line in body)
			out.push(line.length == 0 ? '' : indent + line);
		if (!python)
			out.push('end');
		return out;
	}

	/** Unique modifier names in first-seen order. */
	static function modifierNames(tracks:Array<ModchartLabTrack>):Array<String>
	{
		final out:Array<String> = [];
		for (track in tracks)
		{
			if (out.indexOf(track.modifier) == -1)
				out.push(track.modifier);
		}
		return out;
	}

	/**
	 * Copies of the tracks that actually carry keyframes inside the section,
	 * sorted so the output is stable regardless of recording order.
	 */
	static function usableTracks(tracks:Array<ModchartLabTrack>, length:Float):Array<ModchartLabTrack>
	{
		final out:Array<ModchartLabTrack> = [];
		if (tracks == null)
			return out;
		for (track in tracks)
		{
			if (track == null)
				continue;
			final kept:Array<LabKeyframe> = [];
			for (key in track.snapshot())
			{
				if (key.beat < -ModchartLabTrack.SAME_BEAT || key.beat > length + ModchartLabTrack.SAME_BEAT)
					continue;
				kept.push({beat: Math.max(0, key.beat), value: key.value});
			}
			if (kept.length == 0)
				continue;
			final copy:ModchartLabTrack = new ModchartLabTrack(track.modifier, track.percent, track.player);
			copy.keys = kept;
			out.push(copy);
		}
		out.sort(function(a:ModchartLabTrack, b:ModchartLabTrack):Int {
			final byModifier:Int = compareNames(a.modifier, b.modifier);
			if (byModifier != 0)
				return byModifier;
			final byPercent:Int = compareNames(a.percent, b.percent);
			if (byPercent != 0)
				return byPercent;
			return a.player - b.player;
		});
		return out;
	}

	static function compareNames(a:String, b:String):Int
	{
		final left:String = a == null ? '' : a.toLowerCase();
		final right:String = b == null ? '' : b.toLowerCase();
		return left < right ? -1 : (left > right ? 1 : 0);
	}
}
