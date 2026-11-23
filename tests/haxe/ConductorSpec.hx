import backend.ClientPrefs;
import backend.Conductor;
import data.Section.SwagSection;
import data.Song.SwagSong;
import objects.Note;
import play.PlayState;

/**
 * Renderer-free contract tests for `backend/Conductor.hx` — the timing core of
 * the engine. Covers the tempo-change map and its binary search, the
 * step/beat/row conversions, and the `Rating` class that tallies hits.
 *
 * The production module only needs the Flixel-free stubs under
 * `tests/haxe/stubs/` (ClientPrefs, Song/Section typedefs, an empty Note and a
 * counter-carrying PlayState), so it runs on the Haxe interpreter.
 * Run with:
 *
 *     bash tests/haxe/run-conductor.sh
 */
class ConductorSpec
{
	/** Asserts reference/value equality with a labelled failure message. */
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	/** Asserts float proximity within 0.001. */
	static function near(actual:Float, expected:Float, label:String):Void
	{
		if (Math.abs(actual - expected) > 0.001) throw '$label: expected $expected, got $actual';
	}

	/** Asserts a boolean condition with a labelled failure message. */
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	/** Restore the statics that the production code keeps mutable, so test order does not matter. */
	static function resetConductor():Void
	{
		Conductor.bpm = 100;
		Conductor.crochet = 600;
		Conductor.stepCrochet = 150;
		Conductor.bpmChangeMap = [];
		Conductor.songPosition = 0;
		Conductor.offset = 0;
	}

	/**
	 * The two tempo changes every other timing test shares, set up the way PlayState does it:
	 * the chart is mapped first, then the base tempo is applied with `changeBPM`.
	 * 240 BPM at step 16 (2s), 60 BPM at step 48 (4s).
	 */
	static function changeMap():Array<Dynamic>
	{
		var sections:Array<SwagSection> = [
			{sectionBeats: 4, changeBPM: false, bpm: 120},
			{sectionBeats: 4, changeBPM: true, bpm: 240},
			{sectionBeats: 4, changeBPM: false, bpm: 240},
			{sectionBeats: 3, changeBPM: true, bpm: 60}
		];
		var song:SwagSong = {bpm: 120, notes: sections};
		Conductor.mapBPMChanges(song);
		Conductor.changeBPM(120);
		return cast Conductor.bpmChangeMap;
	}

	/** Runs every spec section in order and resets the shared state afterwards. */
	static function main():Void
	{
		rowConversion();
		crochetMaths();
		bpmChangeMapBuilding();
		bpmLookupBinarySearch();
		timeConversions();
		judgeNoteRouting();
		ratingConstruction();
		ratingLoadDefault();
		ratingIncrease();
		recalculateTimings();

		resetConductor();
		Sys.println('ConductorSpec: PASS');
	}

	/** Covers row conversion. */
	static function rowConversion():Void
	{
		resetConductor();
		equal(Conductor.beatToRow(0), 0, 'row of beat zero');
		equal(Conductor.beatToRow(1), 48, 'row of one beat');
		equal(Conductor.beatToRow(2.5), 120, 'row of two and a half beats');
		equal(Conductor.beatToRow(-1), -48, 'negative beats map to negative rows');
		near(Conductor.rowToBeat(48), 1, 'row back to beat');
		near(Conductor.rowToBeat(1), 1 / 48, 'single row is one 48th of a beat');
		equal(Conductor.secsToRow(0), 0, 'row of time zero');
		// 1 beat at the default 100 BPM is 600 ms -> exactly one beat -> 48 rows.
		// Times in the conductor are milliseconds, not seconds.
		equal(Conductor.secsToRow(600), 48, 'row of time at one beat');
	}

	/** Covers crochet maths. */
	static function crochetMaths():Void
	{
		resetConductor();
		near(Conductor.calculateCrochet(120), 500, 'crotchet at 120 BPM');
		near(Conductor.calculateCrochet(60), 1000, 'crotchet at 60 BPM');

		Conductor.changeBPM(140);
		near(Conductor.bpm, 140, 'changeBPM stores the new bpm');
		near(Conductor.crochet, (60 / 140) * 1000, 'changeBPM recomputes crochet');
		near(Conductor.stepCrochet, Conductor.crochet / 4, 'changeBPM recomputes stepCrochet');
		resetConductor();
	}

	/** Covers bpm change map building. */
	static function bpmChangeMapBuilding():Void
	{
		resetConductor();
		var map = changeMap();
		equal(map.length, 2, 'two tempo changes recorded');
		equal(map[0].stepTime, 16, 'first change step');
		near(map[0].songTime, 2000, 'first change songTime');
		near(map[0].bpm, 240, 'first change bpm');
		near(cast map[0].stepCrochet, 62.5, 'first change stepCrochet');
		equal(map[1].stepTime, 48, 'second change step');
		near(map[1].songTime, 4000, 'second change songTime');
		near(map[1].bpm, 60, 'second change bpm');
		near(cast map[1].stepCrochet, 250, 'second change stepCrochet');

		// A change that matches the running tempo is not recorded twice.
		resetConductor();
		Conductor.mapBPMChanges({
			bpm: 120,
			notes: [
				{sectionBeats: 4, changeBPM: true, bpm: 120}
			]
		});
		equal(Conductor.bpmChangeMap.length, 0, 'change equal to the running bpm is ignored');

		// NaN, zero and negative chart tempos are rejected; the fallback is 100 BPM.
		resetConductor();
		Conductor.mapBPMChanges({
			bpm: Math.NaN,
			notes: [
				{sectionBeats: 4, changeBPM: false, bpm: 0}
			]
		});
		equal(Conductor.bpmChangeMap.length, 0, 'NaN base bpm produces no changes');
		near(Conductor.getBPMFromSeconds(0).bpm, 100, 'NaN base bpm falls back to 100');

		resetConductor();
		Conductor.mapBPMChanges({
			bpm: -50,
			notes: [
				{sectionBeats: 4, changeBPM: false, bpm: 0}
			]
		});
		near(Conductor.getBPMFromSeconds(0).bpm, 100, 'negative base bpm falls back to 100');

		// Invalid section tempos do not produce events of their own.
		resetConductor();
		Conductor.mapBPMChanges({
			bpm: 100,
			notes: [
				{sectionBeats: 4, changeBPM: true, bpm: Math.NaN},
				{sectionBeats: 4, changeBPM: true, bpm: -10},
				{sectionBeats: 4, changeBPM: true, bpm: 0},
				{sectionBeats: 4, changeBPM: true, bpm: 200}
			]
		});
		equal(Conductor.bpmChangeMap.length, 1, 'only the valid tempo change is recorded');
		near(Conductor.bpmChangeMap[0].bpm, 200, 'valid change wins');

		// Sections without a usable length count as four beats, so the tempo
		// that follows them still lands on a whole step.
		resetConductor();
		Conductor.mapBPMChanges({
			bpm: 100,
			notes: [
				{sectionBeats: 0, changeBPM: false, bpm: 0},
				{sectionBeats: -3, changeBPM: false, bpm: 0},
				{sectionBeats: Math.NaN, changeBPM: false, bpm: 0},
				{sectionBeats: 4, changeBPM: true, bpm: 200}
			]
		});
		equal(Conductor.bpmChangeMap.length, 1, 'fallback sections still allow later changes');
		equal(Conductor.bpmChangeMap[0].stepTime, 48, 'three four-beat fallback sections precede the change');

		// Null sections in the chart array consume no tempo-change record of
		// their own, but the step counter still applies the four-beat fallback.
		resetConductor();
		Conductor.mapBPMChanges({
			bpm: 100,
			notes: [null, {sectionBeats: 4, changeBPM: true, bpm: 200}]
		});
		equal(Conductor.bpmChangeMap.length, 1, 'null sections record no change of their own');
		equal(Conductor.bpmChangeMap[0].stepTime, 16, 'null section consumed the four-beat fallback');

		resetConductor();
	}

	/** Covers bpm lookup binary search. */
	static function bpmLookupBinarySearch():Void
	{
		resetConductor();
		changeMap();

		// Before the first change the lookup reports the base tempo.
		near(Conductor.getBPMFromSeconds(0).bpm, 120, 'before the first change: base bpm');
		near(Conductor.getBPMFromSeconds(1999.999).bpm, 120, 'just before the first change: base bpm');
		near(Conductor.getBPMFromSeconds(-500).bpm, 120, 'negative time: base bpm');

		// Boundaries are inclusive of the change itself.
		near(Conductor.getBPMFromSeconds(2000).bpm, 240, 'exactly at the first change');
		near(Conductor.getBPMFromSeconds(3999.999).bpm, 240, 'just before the second change');
		near(Conductor.getBPMFromSeconds(4000).bpm, 60, 'exactly at the second change');
		near(Conductor.getBPMFromSeconds(99999).bpm, 60, 'after the last change');

		// The step-based lookup mirrors it.
		near(Conductor.getBPMFromStep(0).bpm, 120, 'step zero: base bpm');
		near(Conductor.getBPMFromStep(15.999).bpm, 120, 'just before the first change step');
		near(Conductor.getBPMFromStep(16).bpm, 240, 'exactly at the first change step');
		near(Conductor.getBPMFromStep(47.999).bpm, 240, 'just before the second change step');
		near(Conductor.getBPMFromStep(48).bpm, 60, 'exactly at the second change step');

		// An empty map always reports the running base tempo.
		resetConductor();
		near(Conductor.getBPMFromSeconds(12345).bpm, 100, 'empty map: base bpm');
		near(Conductor.getBPMFromStep(12345).bpm, 100, 'empty map: base bpm by step');
		Conductor.changeBPM(90);
		near(Conductor.getBPMFromSeconds(0).bpm, 90, 'empty map: follows changeBPM');
		resetConductor();
	}

	/** Covers time conversions. */
	static function timeConversions():Void
	{
		resetConductor();
		changeMap();

		// beatToSeconds / getStep round-trip across tempo changes.
		near(Conductor.beatToSeconds(0), 0, 'beat zero is time zero');
		near(Conductor.beatToSeconds(4), 2000, 'beat four lands on the first tempo change');
		near(Conductor.beatToSeconds(12), 4000, 'beat twelve lands on the second tempo change');
		near(Conductor.beatToSeconds(15), 7000, 'beat fifteen lands at the end');

		near(Conductor.getStep(2000), 16, 'step at the first change');
		near(Conductor.getStep(4000), 48, 'step at the second change');
		near(Conductor.getStep(2500), 24, 'step between changes');

		near(Conductor.getBeat(2000), 4, 'beat at the first change');
		near(Conductor.getBeat(1000), 2, 'beat at half time');

		// Round-trips stay consistent on both sides of a boundary.
		near(Conductor.getStep(Conductor.beatToSeconds(3)), 12, 'round trip before the first change');
		near(Conductor.getStep(Conductor.beatToSeconds(6)), 24, 'round trip between changes');
		near(Conductor.getStep(Conductor.beatToSeconds(13)), 52, 'round trip after the second change');

		// getStepRounded keeps the integer step but uses the floor of the
		// leftover milliseconds, matching the chart-time used by gameplay.
		near(Conductor.getStepRounded(2010), 16.16, 'rounded step right after a change');
		equal(Conductor.getBeatRounded(2000), 4, 'rounded beat at a change');
		equal(Conductor.getBeatRounded(1999), 3, 'rounded beat just before a change');

		near(Conductor.getCrotchetAtTime(1000), 500, 'crotchet at 120 BPM section');
		near(Conductor.getCrotchetAtTime(2500), 250, 'crotchet at 240 BPM section');
		near(Conductor.getCrotchetAtTime(5000), 1000, 'crotchet at 60 BPM section');
		resetConductor();
	}

	/** Covers judge note routing. */
	static function judgeNoteRouting():Void
	{
		resetConductor();
		var perfect = new Rating('perfect');
		perfect.hitWindow = 22.5;
		var sick = new Rating('sick');
		sick.hitWindow = 50;
		var good = new Rating('good');
		good.hitWindow = 95;
		var bad = new Rating('bad');
		bad.hitWindow = 140;
		var shit = new Rating('shit');
		shit.hitWindow = 180;

		var state = new PlayState();
		state.ratingsData = [perfect, sick, good, bad, shit];
		PlayState.instance = state;

		var note = new Note();
		check(Conductor.judgeNote(note, 0) == perfect, 'zero diff is perfect');
		check(Conductor.judgeNote(note, 22.5) == perfect, 'exact window edge is the tighter rating');
		check(Conductor.judgeNote(note, 22.6) == sick, 'just past the edge falls to the next rating');
		check(Conductor.judgeNote(note, 50) == sick, 'exact sick window edge');
		check(Conductor.judgeNote(note, 90) == good, 'mid window is good');
		check(Conductor.judgeNote(note, 140) == bad, 'exact bad window edge');
		check(Conductor.judgeNote(note, 9999) == shit, 'beyond every window is the last rating');
		check(Conductor.judgeNote(note, 45, true) == perfect, 'botplay always reports the first rating');
		check(Conductor.judgeNote(note, 45, false, true) == perfect, 'a missed note reports the first rating');
		PlayState.instance = null;
	}

	/** Covers rating construction. */
	static function ratingConstruction():Void
	{
		resetConductor();
		equal(new Rating('perfect').counter, 'perfects', 'perfect maps to perfects');
		equal(new Rating('sick').counter, 'sicks', 'sick maps to sicks');
		equal(new Rating('good').counter, 'goods', 'good maps to goods');
		equal(new Rating('bad').counter, 'bads', 'bad maps to bads');
		equal(new Rating('shit').counter, 'poorRatings', 'shit maps to the poorRatings counter');
		equal(new Rating('wat').counter, 'wats', 'mod-defined ratings use the plural convention');

		equal(new Rating('sick').image, 'sick', 'image defaults to the rating name');
		equal(new Rating('good').name, 'good', 'name is stored');
	}

	/** Covers rating load default. */
	static function ratingLoadDefault():Void
	{
		resetConductor();
		ClientPrefs.noMarvJudge = false;
		var withPerfect = Rating.loadDefault();
		equal(withPerfect[0].name, 'perfect', 'perfect leads the default ratings');
		equal(withPerfect.length, 5, 'perfect + sick + good + bad + shit');
		equal(withPerfect[1].score, 350, 'sick score');
		near(withPerfect[1].ratingMod, 1, 'sick rating mod');
		check(withPerfect[1].noteSplash, 'sick shows a splash');
		check(!withPerfect[2].noteSplash, 'good shows no splash');
		equal(withPerfect[withPerfect.length - 1].score, 50, 'poor is worth 50');
		equal(withPerfect[withPerfect.length - 1].counter, 'poorRatings', 'poor tallies poorRatings');

		ClientPrefs.noMarvJudge = true;
		try
		{
			var withoutPerfect = Rating.loadDefault();
			equal(withoutPerfect.length, 4, 'noMarvJudge drops the perfect window');
			equal(withoutPerfect[0].name, 'sick', 'sick leads without perfect');
		}
		catch (e:Dynamic)
		{
			ClientPrefs.noMarvJudge = false;
			throw e;
		}
		ClientPrefs.noMarvJudge = false;
	}

	/** Covers rating increase. */
	static function ratingIncrease():Void
	{
		resetConductor();
		var state = new PlayState();
		state.perfects = 1;
		state.sicks = 2;
		state.goods = 3;
		state.bads = 4;
		state.poorRatings = 5;
		PlayState.instance = state;

		new Rating('perfect').increase();
		new Rating('sick').increase(3);
		new Rating('good').increase();
		new Rating('bad').increase(2);
		new Rating('shit').increase();

		equal(state.perfects, 2, 'perfect tally incremented');
		equal(state.sicks, 5, 'sick tally incremented by three');
		equal(state.goods, 4, 'good tally incremented');
		equal(state.bads, 6, 'bad tally incremented by two');
		equal(state.poorRatings, 6, 'poor tally incremented');

		// A mod-defined counter name with no PlayState field must not throw;
		// every built-in counter stays untouched.
		new Rating('flub').increase();
		new Rating('flub').increase(); // second call exercises the cached-miss path
		equal(state.perfects, 2, 'bogus counter leaves perfects alone');
		equal(state.sicks, 5, 'bogus counter leaves sicks alone');

		// A null instance (e.g. results screen after teardown) is a safe no-op.
		PlayState.instance = null;
		new Rating('sick').increase();

		PlayState.instance = new PlayState();
	}

	/** Covers recalculate timings. */
	static function recalculateTimings():Void
	{
		resetConductor();
		var oldSafeFrames = ClientPrefs.safeFrames;
		ClientPrefs.safeFrames = 12;
		Conductor.recalculateTimings();
		near(Conductor.safeZoneOffset, 200, 'safeZoneOffset floors the safeFrames window');
		near(Conductor.timeScale, 200 / 180, 'timeScale derives from the floored offset');

		ClientPrefs.safeFrames = oldSafeFrames;
		Conductor.recalculateTimings();
		near(Conductor.safeZoneOffset, Math.floor((oldSafeFrames / 60) * 1000), 'previous window restored');
	}
}
