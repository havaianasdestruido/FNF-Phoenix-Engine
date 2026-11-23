import states.ResultsData;
import play.PlayState;

/**
 * Renderer-free contract tests for `states/ResultsData.hx` — the immutable-ish
 * snapshot the results screen and week-end summary are built from. Covers
 * per-song ingestion, week-level aggregation (`addSong`), the FC tier ladder,
 * and the accuracy clamp. The module only needs `backend.CoolUtil` (a difficulty
 * table) and `play.PlayState` (plain data), so it runs on the interpreter.
 * Run with:
 *
 *     bash tests/haxe/run-results-data.sh
 */
class ResultsDataSpec
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

	/** Build a song snapshot with just the counters a test cares about. */
	static function songSnapshot(?score:Float = 0, ?totalPlayed:Int = 0, ?accuracy:Float = 0, ?perfects:Int = 0,
		?sicks:Int = 0, ?goods:Int = 0, ?bads:Int = 0, ?poors:Int = 0, ?misses:Float = 0,
		?maxCombo:Float = 0, ?peakNPS:Float = 0):ResultsData
	{
		var r = new ResultsData('Test', 'Hard');
		r.score = score;
		r.totalPlayed = totalPlayed;
		r.accuracy = accuracy;
		r.perfects = perfects;
		r.sicks = sicks;
		r.goods = goods;
		r.bads = bads;
		r.poors = poors;
		r.misses = misses;
		r.maxCombo = maxCombo;
		r.peakNPS = peakNPS;
		return r;
	}

	/** Runs every spec section in order and resets the shared state afterwards. */
	static function main():Void
	{
		defaults();
		fromPlayState();
		addSongAggregatesCounters();
		addSongWeighsAccuracy();
		addSongCopiesOffsetsAndFcStrings();
		fcTierLadder();
		fcTierCustomStrings();

		Sys.println('ResultsDataSpec: PASS');
	}

	/** Covers defaults. */
	static function defaults():Void
	{
		var r = new ResultsData('Sarvente', 'Normal');
		equal(r.title, 'Sarvente', 'title stored');
		equal(r.difficulty, 'Normal', 'difficulty stored');
		near(r.score, 0, 'score defaults to zero');
		near(r.accuracy, 0, 'accuracy defaults to zero');
		equal(r.totalPlayed, 0, 'no notes played by default');
		equal(r.fcTier, 'No Play', 'unplayed tier');
		equal(r.fcStrings.length, 0, 'no fc strings by default');
		equal(r.hitOffsets.length, 0, 'no offsets by default');
	}

	/** Covers from play state. */
	static function fromPlayState():Void
	{
		var oldDifficulty = PlayState.storyDifficulty;
		PlayState.storyDifficulty = 2; // Hard in the stub table

		var state = new PlayState();
		state.songScore = 123456;
		state.totalPlayed = 100;
		state.totalNotesHit = 92.5;
		state.perfects = 30;
		state.sicks = 40;
		state.goods = 10;
		state.bads = 5;
		state.poorRatings = 4;
		state.songMisses = 11;
		state.maxCombo = 87;
		state.maxNPS = 14.5;
		state.fcStrings = ['No Play', 'PFC', 'SFC', 'GFC', 'BFC', 'FC', 'SDCB', 'Clear', 'TDCB', 'QDCB'];
		state.ratingFC = 'SFC';
		state.hitOffsets = [1.5, -2.25];

		var result = ResultsData.fromPlayState(state, 'Dad Battle');

		equal(result.title, 'Dad Battle', 'title passed through');
		equal(result.difficulty, 'Hard', 'difficulty resolved from the story difficulty');
		near(result.score, 123456, 'score mapped');
		near(result.accuracy, 92.5, 'accuracy computed from notes hit / played');
		equal(result.totalPlayed, 100, 'notes played mapped');
		equal(result.perfects, 30, 'perfects mapped');
		equal(result.sicks, 40, 'sicks mapped');
		equal(result.goods, 10, 'goods mapped');
		equal(result.bads, 5, 'bads mapped');
		equal(result.poors, 4, 'poors mapped from poorRatings');
		near(result.misses, 11, 'misses mapped');
		near(result.maxCombo, 87, 'max combo mapped');
		near(result.peakNPS, 14.5, 'peak NPS mapped');
		equal(result.fcTier, 'SFC', 'fc tier mapped from ratingFC');
		equal(result.hitOffsets.length, 2, 'offsets copied');
		check(result.hitOffsets != state.hitOffsets, 'offsets are a copy, not the same array');
		check(result.fcStrings != state.fcStrings, 'fc strings are a copy, not the same array');

		// Accuracy is clamped into 0..100 both ways.
		var lucky = new PlayState();
		lucky.totalPlayed = 10;
		lucky.totalNotesHit = 25; // impossible in game, must clamp
		near(ResultsData.fromPlayState(lucky, 'x').accuracy, 100, 'accuracy clamps at 100');

		var unlucky = new PlayState();
		unlucky.totalPlayed = 10;
		unlucky.totalNotesHit = -3; // impossible in game, must clamp
		near(ResultsData.fromPlayState(unlucky, 'x').accuracy, 0, 'accuracy clamps at 0');

		// No notes played: accuracy is zero, not NaN.
		var idle = new PlayState();
		idle.totalPlayed = 0;
		near(ResultsData.fromPlayState(idle, 'x').accuracy, 0, 'zero notes gives zero accuracy');

		// Empty or missing FC tier becomes 'No Play'.
		var plain = new PlayState();
		plain.ratingFC = '';
		equal(ResultsData.fromPlayState(plain, 'x').fcTier, 'No Play', 'empty ratingFC becomes No Play');
		plain.ratingFC = null;
		equal(ResultsData.fromPlayState(plain, 'x').fcTier, 'No Play', 'null ratingFC becomes No Play');

		PlayState.storyDifficulty = oldDifficulty;
	}

	/** Covers add song aggregates counters. */
	static function addSongAggregatesCounters():Void
	{
		var total = songSnapshot(1000, 50, 80, 10, 20, 5, 4, 3, 8, 40, 9);
		var song = songSnapshot(2500, 60, 90, 5, 30, 10, 2, 1, 12, 55, 11);
		var before = total.fcStrings;
		total.addSong(song);

		near(total.score, 3500, 'scores add');
		equal(total.totalPlayed, 110, 'notes played add');
		equal(total.perfects, 15, 'perfects add');
		equal(total.sicks, 50, 'sicks add');
		equal(total.goods, 15, 'goods add');
		equal(total.bads, 6, 'bads add');
		equal(total.poors, 4, 'poors add');
		near(total.misses, 20, 'misses add');
		near(total.maxCombo, 55, 'max combo takes the larger value');
		near(total.peakNPS, 11, 'peak NPS takes the larger value');
	}

	/** Covers add song weighs accuracy. */
	static function addSongWeighsAccuracy():Void
	{
		// 100% over 100 notes then 50% over 50 notes: (100*100 + 50*50) / 150.
		var week = songSnapshot(0, 100, 100);
		week.addSong(songSnapshot(0, 50, 50));
		near(week.accuracy, (100 * 100 + 50 * 50) / 150, 'accuracy is weighted by notes played');

		// Folding in a second song of equal weight is a plain average.
		var both = songSnapshot(0, 100, 80);
		both.addSong(songSnapshot(0, 100, 60));
		near(both.accuracy, 70, 'equal-weight accuracy averages');

		// An empty song changes nothing (and must not produce NaN).
		var untouched = songSnapshot(0, 0, 0);
		untouched.addSong(songSnapshot(0, 0, 0));
		near(untouched.accuracy, 0, 'zero combined notes keeps zero accuracy');
		equal(untouched.totalPlayed, 0, 'zero combined notes stays zero');
	}

	/** Covers add song copies offsets and fc strings. */
	static function addSongCopiesOffsetsAndFcStrings():Void
	{
		var week = new ResultsData('Week', 'Hard');
		week.hitOffsets.push(1);
		week.hitOffsets.push(2);
		var song = songSnapshot();
		song.hitOffsets.push(30);
		song.hitOffsets.push(40);
		song.fcStrings = ['only', 'from', 'song'];
		week.addSong(song);

		equal(week.hitOffsets.length, 4, 'offsets are concatenated');
		equal(week.hitOffsets[0], 1, 'base offsets come first');
		equal(week.hitOffsets[3], 40, 'song offsets are appended');
		equal(week.fcStrings.length, 3, 'fc strings from a played song replace the base list');
		equal(week.fcStrings[0], 'only', 'fc strings content comes from the song');
		check(week.fcStrings != song.fcStrings, 'fc strings are copied, not aliased');

		// A song without fc strings leaves the accumulated list alone.
		var accumulated = new ResultsData('Week', 'Hard');
		accumulated.fcStrings = ['keep', 'me'];
		var empty = songSnapshot();
		empty.totalPlayed = 10;
		empty.perfects = 10;
		for (i in 0...5) accumulated.addSong(empty);
		equal(accumulated.fcStrings.length, 2, 'empty fc strings leave the accumulated list untouched');
	}

	/** Covers fc tier ladder. */
	static function fcTierLadder():Void
	{
		// Each tier of the ladder, from the combined totals after aggregation.
		// Perfect-only play is PFC; any sick drops it to SFC; and so on down to
		// QDCB for a thousand misses.
		function tierWith(?perfects:Int = 0, ?sicks:Int = 0, ?goods:Int = 0, ?bads:Int = 0, ?poors:Int = 0, ?misses:Float = 0):String
		{
			var total = new ResultsData('Week', 'Hard');
			var played = perfects + sicks + goods + bads + poors + Std.int(misses);
			var song = songSnapshot(0, played, 0, perfects, sicks, goods, bads, poors, misses);
			total.addSong(song);
			return total.fcTier;
		}

		equal(tierWith(0), 'No Play', 'nothing played at all keeps No Play');
		equal(tierWith(5), 'PFC', 'perfect-only play is PFC');
		equal(tierWith(5, 1), 'SFC', 'any sick downgrades to SFC');
		equal(tierWith(0, 1), 'SFC', 'a sick alone scores SFC');
		equal(tierWith(0, 3, 2), 'GFC', 'goods downgrade to GFC');
		equal(tierWith(0, 3, 0, 1), 'BFC', 'bads downgrade to BFC (but not past poors)');
		equal(tierWith(0, 3, 0, 0, 1), 'FC', 'poors take the FC slot');
		equal(tierWith(0, 0, 0, 0, 0, 1), 'SDCB', 'one miss lands on SDCB');
		equal(tierWith(0, 0, 0, 0, 0, 9), 'SDCB', 'nine misses are still SDCB');
		equal(tierWith(0, 0, 0, 0, 0, 10), 'Clear', 'ten misses clear to Clear');
		equal(tierWith(0, 0, 0, 0, 0, 99), 'Clear', 'ninety-nine misses are still Clear');
		equal(tierWith(0, 0, 0, 0, 0, 100), 'TDCB', 'a hundred misses drop to TDCB');
		equal(tierWith(0, 0, 0, 0, 0, 999), 'TDCB', 'nine hundred ninety-nine misses are still TDCB');
		equal(tierWith(0, 0, 0, 0, 0, 1000), 'QDCB', 'a thousand misses drop to QDCB');

		// The ladder is ordered by severity: misses outrank poors, which
		// outrank bads, which outrank goods, which outrank sicks.
		equal(tierWith(4, 4, 4, 4, 4, 5), 'SDCB', 'any miss outranks everything else');
		equal(tierWith(4, 4, 4, 4, 1), 'FC', 'poors outrank bads');
		equal(tierWith(4, 4, 4, 1), 'BFC', 'bads outrank goods');
		equal(tierWith(4, 4, 1), 'GFC', 'goods outrank sicks');
	}

	/** Covers fc tier custom strings. */
	static function fcTierCustomStrings():Void
	{
		// A mod that ships ten custom FC strings names the tiers itself.
		var week = new ResultsData('Week', 'Hard');
		week.fcStrings = ['t0', 't1', 't2', 't3', 't4', 't5', 't6', 't7', 't8', 't9'];
		var song = songSnapshot(0, 10, 0, 10, 0, 0, 0, 0, 0); // perfects only
		week.addSong(song);
		equal(week.fcTier, 't1', 'perfect play honours the custom tier list');

		var missy = new ResultsData('Week', 'Hard');
		missy.fcStrings = ['t0', 't1', 't2', 't3', 't4', 't5', 't6', 't7', 't8', 't9'];
		missy.addSong(songSnapshot(0, 10, 0, 0, 0, 0, 0, 0, 1000));
		equal(missy.fcTier, 't9', 'a thousand misses honour the custom tier list');
	}
}
