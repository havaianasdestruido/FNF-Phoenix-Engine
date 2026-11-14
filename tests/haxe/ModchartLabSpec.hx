import modchart.ModchartEase;
import modchart.ModchartOutput;
import modchart.ModchartParams;
import modchart.ModchartVec3;
import modchart.ModifierRegistry;
import modchart.PlayField;
import modchart.lab.LabLanguage;
import modchart.lab.LabKeyframe;
import modchart.lab.ModchartLabCatalog;
import modchart.lab.ModchartLabExport;
import modchart.lab.ModchartLabExportOptions;
import modchart.lab.ModchartLabTrack;

/**
 * Contract tests for the Modchart Lab core (`modchart.lab.*`): the knob
 * catalog, the recorded automation and the generated Lua/Python text.
 *
 * The lab core is renderer-free so this runs on the Haxe interpreter without
 * Flixel, exactly like `ModchartSpec`. The last group also proves that every
 * catalog percent actually moves its modifier, which is what makes the
 * catalog (rather than a copy of the docs) the source of truth for the
 * editor's sliders.
 */
class ModchartLabSpec
{
	static function check(ok:Bool, label:String):Void
	{
		if (!ok)
			throw label;
	}

	static function equals(actual:String, expected:String, label:String):Void
	{
		if (actual != expected)
			throw label + ':\n--- expected ---\n' + expected + '\n--- actual ---\n' + actual;
	}

	static function approx(actual:Float, expected:Float, label:String):Void
	{
		if (Math.abs(actual - expected) > 0.001)
			throw '$label: expected $expected, got $actual';
	}

	static function main():Void
	{
		catalogCoverage();
		catalogShape();
		trackRecording();
		trackEvaluation();
		trackHousekeeping();
		exportOnceLua();
		exportOncePython();
		exportLoopLua();
		exportPlayerAndEdges();
		exportFormatting();
		knobsDriveModifiers();
		Sys.println('ModchartLabSpec: PASS');
	}

	// ------------------------------------------------------------------
	// Catalog
	// ------------------------------------------------------------------

	static function catalogCoverage():Void
	{
		final missing:Array<String> = ModchartLabCatalog.missing();
		check(missing.length == 0, 'every registry modifier has a catalog entry, missing: ' + missing.join(', '));

		final names:Array<String> = ModifierRegistry.names();
		check(names.length == 34, 'registry still ships 34 modifiers, got ' + names.length);
		check(ModchartLabCatalog.all().length == names.length, 'catalog size matches the registry');
		for (name in names)
		{
			final entry = ModchartLabCatalog.find(name);
			check(entry != null, 'catalog lookup works for ' + name);
			check(entry.name == name, 'catalog name is the registry name for ' + name);
			check(entry.label.length > 0, 'catalog label is not empty for ' + name);
			check(entry.hint.length > 0, 'catalog hint is not empty for ' + name);
		}
		check(ModchartLabCatalog.find('DRUNK') != null, 'catalog lookup is case-insensitive');
		check(ModchartLabCatalog.find('not-a-modifier') == null, 'unknown modifiers return null');
		check(ModchartLabCatalog.knobs('not-a-modifier').length == 0, 'unknown modifiers have no knobs');
	}

	static function catalogShape():Void
	{
		for (entry in ModchartLabCatalog.all())
		{
			check(entry.knobs.length > 0, 'at least one knob for ' + entry.name);
			var mains:Int = 0;
			final seen:Array<String> = [];
			for (knob in entry.knobs)
			{
				final label:String = entry.name + '.' + knob.percent;
				check(knob.min < knob.max, label + ' has a usable range');
				check(knob.step > 0, label + ' has a positive step');
				check(knob.value >= knob.min && knob.value <= knob.max, label + ' default sits inside the range');
				check(knob.percent.length >= 1 && knob.percent.indexOf(' ') == -1, label + ' is a single percent token');
				check(seen.indexOf(knob.percent.toLowerCase()) == -1, label + ' is not repeated');
				seen.push(knob.percent.toLowerCase());
				if (knob.main)
					mains++;
			}
			check(mains == 1, entry.name + ' flags exactly one main knob, got ' + mains);
			check(ModchartLabCatalog.mainKnob(entry.name) != null, 'main knob resolves for ' + entry.name);
			check(ModchartLabCatalog.knob(entry.name, entry.knobs[0].percent.toUpperCase()) != null, 'knob lookup is case-insensitive');
			check(ModchartLabCatalog.knob(entry.name, 'definitely-not-a-percent') == null, 'unknown percent returns null');
		}
		// A couple of spot checks so a range regression in the table is caught.
		approx(ModchartLabCatalog.knob('scale', 'scale').value, 1, 'scale ships at 1');
		approx(ModchartLabCatalog.knob('reverse', 'xmod').value, 1, 'reverse xmod ships at 1');
		approx(ModchartLabCatalog.knob('stealth', 'alpha').value, 1, 'stealth alpha ships at 1');
		check(ModchartLabCatalog.knob('transform', 'x').max > 100, 'transform x is measured in pixels');
	}

	// ------------------------------------------------------------------
	// Track recording
	// ------------------------------------------------------------------

	static function trackRecording():Void
	{
		final track:ModchartLabTrack = new ModchartLabTrack('drunk', 'drunk');
		check(track.isEmpty() == true && track.count() == 0, 'new track is empty');
		check(track.record(2, 0.5) == true, 'recording a key reports a change');
		check(track.record(0, 0.1) == true, 'recording an earlier beat inserts in order');
		check(track.record(1, 0.2) == true, 'recording a middle beat inserts in order');
		check(track.keys.length == 3, 'three keys recorded');
		approx(track.keys[0].beat, 0, 'keys are sorted (0)');
		approx(track.keys[1].beat, 1, 'keys are sorted (1)');
		approx(track.keys[2].beat, 2, 'keys are sorted (2)');

		check(track.record(2, 0.5) == false, 'recording the same value is a no-op');
		check(track.record(2.0002, 0.9) == true, 'recording inside the same beat rewrites the key');
		approx(track.keys[2].value, 0.9, 'same-beat rewrite keeps one key');
		check(track.keys.length == 3, 'same-beat rewrite does not add a key');

		// Spacing keeps a fast drag from piling keys into the same bucket.
		final spaced:ModchartLabTrack = new ModchartLabTrack('drunk', 'drunk', 1);
		spaced.record(0, 0.2, 0.25);
		check(spaced.record(0.1, 0.4, 0.25) == true, 'inside the spacing bucket reports the new value');
		approx(spaced.keys.length, 1, 'spacing updates the bucket key instead of appending');
		approx(spaced.keys[0].value, 0.4, 'spacing keeps the bucket value fresh');
		approx(spaced.keys[0].beat, 0, 'spacing keeps the bucket beat');
		check(spaced.record(0.5, 0.6, 0.25) == true, 'outside the bucket appends');
		approx(spaced.keys.length, 2, 'a second bucket adds a key');

		check(track.record(Math.NaN, 1) == false, 'NaN beats are ignored');
		check(track.record(3, Math.POSITIVE_INFINITY) == false, 'non-finite values are ignored');

		check(track.matches('DRUNK', 'Drunk', -1), 'track matching is case-insensitive');
		check(!track.matches('drunk', 'drunk', 1), 'track matching respects the side');
	}

	static function trackEvaluation():Void
	{
		final track:ModchartLabTrack = new ModchartLabTrack('drunk', 'drunk');
		approx(track.valueAt(1, ModchartEase.linear, 0.7), 0.7, 'empty track falls back');

		track.record(2, 0.2);
		track.record(6, 1);
		approx(track.valueAt(0, ModchartEase.linear), 0.2, 'value is held before the first key');
		approx(track.valueAt(2, ModchartEase.linear), 0.2, 'first key is honoured');
		approx(track.valueAt(4, ModchartEase.linear), 0.6, 'linear midpoint between keys');
		approx(track.valueAt(6, ModchartEase.linear), 1, 'last key is honoured');
		approx(track.valueAt(9, ModchartEase.linear), 1, 'value is held after the last key');
		approx(track.valueAt(4, ModchartEase.quadOut), 0.8, 'segment uses the chosen ease');
		approx(track.valueAt(4, null), 0.6, 'null ease is linear');

		// A single key holds everywhere, which is what the exporter emits as one modSet.
		final single:ModchartLabTrack = new ModchartLabTrack('bounce', 'bounce');
		single.record(3, 0.5);
		approx(single.valueAt(0, ModchartEase.linear), 0.5, 'single key holds before');
		approx(single.valueAt(7, ModchartEase.linear), 0.5, 'single key holds after');
	}

	static function trackHousekeeping():Void
	{
		final track:ModchartLabTrack = new ModchartLabTrack('drunk', 'drunk');
		track.record(0, -0.5);
		track.record(2, 0.25);
		track.record(4, 1.5);
		approx(track.minValue(), -0.5, 'min value');
		approx(track.maxValue(), 1.5, 'max value');

		final copy:Array<LabKeyframe> = track.snapshot();
		check(copy.length == 3, 'snapshot copies the keys');
		copy[0].value = 99;
		approx(track.keys[0].value, -0.5, 'snapshot is a copy');

		check(track.clip(2) == 1, 'clip drops keys past the section end');
		check(track.keys.length == 2, 'clip leaves the keys inside');
		check(track.clip(10) == 0, 'clip is a no-op when everything fits');

		track.clear();
		check(track.isEmpty(), 'clear empties the track');
		approx(track.minValue(), 0, 'empty track min is 0');
	}

	// ------------------------------------------------------------------
	// Export
	// ------------------------------------------------------------------

	static function fixture():Array<ModchartLabTrack>
	{
		final drunk:ModchartLabTrack = new ModchartLabTrack('drunk', 'drunk');
		drunk.record(0, 0);
		drunk.record(2, 0.5);
		drunk.record(4, 0.25);
		return [drunk];
	}

	static function options(?language:LabLanguage = Lua, ?loop:Bool = false):ModchartLabExportOptions
	{
		final options:ModchartLabExportOptions = new ModchartLabExportOptions();
		options.language = language;
		options.loop = loop;
		options.startBeat = 4;
		options.length = 8;
		options.ease = 'quadOut';
		return options;
	}

	static function exportOnceLua():Void
	{
		final expected:String = [
			'-- Modchart Lab - Phoenix Engine',
			'-- Section: beats 4 -> 12 (8 beats), ease quadOut',
			'-- Paste into a Lua script; merge the bodies if you already have these callbacks.',
			'',
			'function onCreatePost()',
			"\taddModifier('drunk')",
			'',
			"\tmodSet('drunk', 4, 0)",
			"\tmodEase('drunk', 4, 2, 0.5, 'quadOut')",
			"\tmodEase('drunk', 6, 2, 0.25, 'quadOut')",
			'end'
		].join('\n');
		equals(ModchartLabExport.generate(fixture(), options()), expected, 'once-mode Lua export');
	}

	static function exportOncePython():Void
	{
		final expected:String = [
			'# Modchart Lab - Phoenix Engine',
			'# Section: beats 4 -> 12 (8 beats), ease quadOut',
			'# Paste into a Python script; merge the bodies if you already have these callbacks.',
			'',
			'def onCreatePost():',
			"    addModifier('drunk')",
			'',
			"    modSet('drunk', 4, 0)",
			"    modEase('drunk', 4, 2, 0.5, 'quadOut')",
			"    modEase('drunk', 6, 2, 0.25, 'quadOut')"
		].join('\n');
		equals(ModchartLabExport.generate(fixture(), options(Python)), expected, 'once-mode Python export');
	}

	static function exportLoopLua():Void
	{
		final expected:String = [
			'-- Modchart Lab - Phoenix Engine',
			'-- Looping section: 8 beats from beat 4, ease quadOut',
			'-- Paste into a Lua script; merge the bodies if you already have these callbacks.',
			'',
			'function onCreatePost()',
			"\taddModifier('drunk')",
			'',
			"\tmodRepeater(4, 8, 'onModchartLabSection')",
			'end',
			'',
			'function onModchartLabSection(beat)',
			"\tmodSet('drunk', beat, 0)",
			"\tmodEase('drunk', beat, 2, 0.5, 'quadOut')",
			"\tmodEase('drunk', beat + 2, 2, 0.25, 'quadOut')",
			'end'
		].join('\n');
		equals(ModchartLabExport.generate(fixture(), options(Lua, true)), expected, 'loop-mode Lua export');
	}

	static function exportPlayerAndEdges():Void
	{
		final drunk:ModchartLabTrack = new ModchartLabTrack('drunk', 'drunk');
		drunk.record(0, 0.2);
		final bounce:ModchartLabTrack = new ModchartLabTrack('bounce', 'bounce', 1);
		bounce.record(2, 0.5);
		bounce.record(4, 0.9);
		final text:String = ModchartLabExport.generate([drunk, bounce], options());

		// Tracks are sorted by modifier, every used modifier is installed once.
		check(text.indexOf("addModifier('bounce')") < text.indexOf("addModifier('drunk')"), 'bounce is installed before drunk');
		equals(Std.string(occurrences(text, "addModifier('bounce')")), '1', 'bounce is installed once');
		check(text.indexOf("\taddModifier('drunk')") != -1, 'drunk is installed');
		check(text.indexOf("\tmodSet('bounce', 4, 0.5, 1)") != -1, 'player argument is emitted for a one-sided track');
		check(text.indexOf("modEase('bounce', 6, 2, 0.9, 'quadOut', 1)") != -1, 'modEase keeps the player after the ease');
		check(text.indexOf("\tmodSet('drunk', 4, 0.2)") != -1, 'both-sided tracks omit the player');

		// Keys outside the section are dropped, keys past it are not exported.
		final outside:ModchartLabTrack = new ModchartLabTrack('drunk', 'drunkX');
		outside.record(2, 0.4);
		outside.record(30, 1);
		final clipped:String = ModchartLabExport.generate([outside], options());
		check(clipped.indexOf('30') == -1, 'keys past the section end are not exported');
		check(clipped.indexOf("modSet('drunkX', 4, 0.4)") != -1, 'the surviving key is exported');

		// Nothing recorded still produces a usable hint instead of empty code.
		final empty:String = ModchartLabExport.generate([], options());
		check(empty.indexOf('Nothing recorded yet') != -1, 'empty export explains what to do');
		check(empty.indexOf('function') == -1, 'empty export has no function body');
		final defaults:String = ModchartLabExport.generate(null, null);
		check(defaults.indexOf('beats 0 -> 8 (8 beats), ease quadOut') != -1, 'null tracks/options fall back to the defaults');
		check(defaults.indexOf('Nothing recorded yet') != -1, 'null tracks export the hint');
	}

	static function exportFormatting():Void
	{
		equals(ModchartLabExport.number(0), '0', 'zero');
		equals(ModchartLabExport.number(-0.0), '0', 'negative zero');
		equals(ModchartLabExport.number(2), '2', 'integer');
		equals(ModchartLabExport.number(0.5), '0.5', 'fraction');
		equals(ModchartLabExport.number(0.30000000000000004), '0.3', 'float noise is trimmed');
		equals(ModchartLabExport.number(-1.25), '-1.25', 'negatives keep their sign');
		equals(ModchartLabExport.number(Math.NaN), '0', 'NaN is safe');
		equals(ModchartLabExport.number(Math.POSITIVE_INFINITY), '0', 'infinity is safe');

		equals(ModchartLabExport.canonicalEase('QUADOUT'), 'quadOut', 'ease spelling is canonical');
		equals(ModchartLabExport.canonicalEase(' sineInOut '), 'sineInOut', 'ease lookup trims');
		equals(ModchartLabExport.canonicalEase('nope'), 'linear', 'unknown ease falls back like the runtime');
		equals(ModchartLabExport.canonicalEase(null), 'linear', 'null ease is linear');
		equals(ModchartLabExport.nextEase('linear', -1), ModchartLabExport.EASES[ModchartLabExport.EASES.length - 1], 'ease cycles backwards');
		equals(ModchartLabExport.nextEase('quadOut', 1), 'quadInOut', 'ease steps forwards');

		equals(ModchartLabExport.identifier('onModchartLabSection', 'fallback'), 'onModchartLabSection', 'valid identifier passes');
		equals(ModchartLabExport.identifier('2bad name', 'fallback'), 'fallback', 'invalid identifier falls back');
		equals(ModchartLabExport.identifier(null, 'fallback'), 'fallback', 'null identifier falls back');
		equals(ModchartLabExport.quote("it's"), "'it\\'s'", 'quotes are escaped');

		// Every ease the picker offers must resolve to a real ease in the runtime.
		final linear:Float->Float = ModchartEase.byName('definitely-not-an-ease');
		for (ease in ModchartLabExport.EASES)
		{
			final resolved:Float->Float = ModchartEase.byName(ease);
			check(resolved != null, 'ease resolves: ' + ease);
			if (ease != 'linear')
				check(resolved(0.37) != linear(0.37) || resolved(0.62) != linear(0.62), 'ease is not a silent linear fallback: ' + ease);
		}

		// A custom callback name survives into the loop export.
		final custom:ModchartLabExportOptions = options(Lua, true);
		custom.callbackName = 'onDrop';
		final text:String = ModchartLabExport.generate(fixture(), custom);
		check(text.indexOf("modRepeater(4, 8, 'onDrop')") != -1, 'custom callback is scheduled');
		check(text.indexOf('function onDrop(beat)') != -1, 'custom callback is defined');
		custom.callbackName = '';
		check(ModchartLabExport.generate(fixture(), custom).indexOf("'onModchartLabSection'") != -1, 'empty callback falls back');
	}

	/** Number of times `needle` appears in `haystack`. */
	static function occurrences(haystack:String, needle:String):Int
	{
		var count:Int = 0;
		var index:Int = haystack.indexOf(needle);
		while (index != -1)
		{
			count++;
			index = haystack.indexOf(needle, index + needle.length);
		}
		return count;
	}

	// ------------------------------------------------------------------
	// The catalog's percents must actually move the modifiers
	// ------------------------------------------------------------------

	/**
	 * Drives every modifier's main knob through a small param grid and fails
	 * when nothing moves. This is the guard that keeps the editor's sliders
	 * honest: a typo in a percent name would otherwise be a silent no-op that
	 * nobody notices until a chart is published.
	 */
	static function knobsDriveModifiers():Void
	{
		// Stored-only (Flixel cannot draw skew) and intentionally random.
		final visualOnly:Array<String> = ['skew'];
		final nonDeterministic:Array<String> = ['vibrate'];

		for (entry in ModchartLabCatalog.all())
		{
			final knob = ModchartLabCatalog.mainKnob(entry.name);
			check(knob != null, 'main knob exists for ' + entry.name);

			final candidates:Array<Float> = [knob.min + (knob.max - knob.min) * 0.25, knob.min + (knob.max - knob.min) * 0.75, 0];
			var changed:Bool = false;
			for (candidate in candidates)
			{
				if (Math.abs(candidate - knob.value) <= 0.0001)
					continue;
				if (sampleDiffers(entry.name, knob.percent, candidate))
				{
					changed = true;
					break;
				}
			}

			if (visualOnly.indexOf(entry.name) != -1)
			{
				check(skewVisuals(entry.name, knob.percent) != 0, entry.name + ' is stored in visuals even if it is not drawn');
				continue;
			}
			if (nonDeterministic.indexOf(entry.name) != -1)
			{
				check(nonDeterministicJitter(entry.name, knob.percent), entry.name + ' jitters the position');
				continue;
			}
			check(changed, entry.name + ' reacts to its main knob (' + knob.percent + ')');
		}
	}

	/** Runs a param grid through a fresh playfield, comparing baseline vs a set percent. */
	static function sampleDiffers(name:String, percent:String, value:Float):Bool
	{
		final base:PlayField = probeField(name, null, 0);
		final probe:PlayField = probeField(name, percent, value);
		for (player in 0...2)
		{
			for (lane in 0...4)
			{
				for (distance in [0.0, 120.0, 250.0, 420.0])
				{
					for (beat in [4.0, 4.25, 4.5, 4.75])
					{
						final baseline:ModchartOutput = base.transform(probePos(player, lane, distance), probeParams(lane, player, distance, beat));
						final modified:ModchartOutput = probe.transform(probePos(player, lane, distance), probeParams(lane, player, distance, beat));
						if (Math.abs(baseline.pos.x - modified.pos.x) > 0.0001
							|| Math.abs(baseline.pos.y - modified.pos.y) > 0.0001
							|| Math.abs(baseline.pos.z - modified.pos.z) > 0.0001
							|| Math.abs(baseline.visuals.alpha - modified.visuals.alpha) > 0.0001
							|| Math.abs(baseline.visuals.angleZ - modified.visuals.angleZ) > 0.0001
							|| Math.abs(baseline.visuals.scaleX - modified.visuals.scaleX) > 0.0001
							|| Math.abs(baseline.visuals.scaleY - modified.visuals.scaleY) > 0.0001)
							return true;
					}
				}
			}
		}
		return false;
	}

	static function skewVisuals(name:String, percent:String):Float
	{
		final probe:PlayField = probeField(name, percent, 1);
		final out:ModchartOutput = probe.transform(probePos(1, 0, 0), probeParams(0, 1, 0, 4));
		return Math.abs(out.visuals.skewX);
	}

	static function nonDeterministicJitter(name:String, percent:String):Bool
	{
		final probe:PlayField = probeField(name, percent, 2);
		final spawnX:Float = 100 + 1 * 600;
		var moved:Bool = false;
		for (_ in 0...32)
		{
			final out:ModchartOutput = probe.transform(probePos(1, 0, 100), probeParams(0, 1, 100, 4));
			if (Math.abs(out.pos.x - spawnX) > 0.0001)
				moved = true;
		}
		return moved;
	}

	static function probeField(name:String, percent:String, value:Float):PlayField
	{
		final field:PlayField = new PlayField();
		field.screenWidth = 1280;
		field.screenHeight = 720;
		field.keyCount = 4;
		field.scrollSpeed = 0.45;
		field.crochet = 500;
		field.receptorX = [[100, 200, 300, 400], [700, 800, 900, 1000]];
		field.receptorY = [[50, 50, 50, 50], [50, 50, 50, 50]];
		field.addModifier(name);
		if (percent != null)
			field.setPercent(percent, value, -1);
		return field;
	}

	/** Resting position of a preview arrow: receptor line plus the scroll distance. */
	static function probePos(player:Int, lane:Int, distance:Float):ModchartVec3
	{
		return new ModchartVec3(100 + lane * 100 + player * 600, 50 + distance, 0);
	}

	static function probeParams(lane:Int, player:Int, distance:Float, beat:Float):ModchartParams
	{
		final params:ModchartParams = new ModchartParams();
		params.songTime = 1200;
		params.curBeat = beat;
		params.distance = distance;
		params.lane = lane;
		params.player = player;
		params.isTapArrow = true;
		params.isReceptor = distance == 0;
		params.receptorX = 100 + lane * 100 + player * 600;
		params.receptorY = 50;
		return params;
	}
}
