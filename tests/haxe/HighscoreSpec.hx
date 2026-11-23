import backend.Highscore;
import flixel.FlxG;

/**
 * Renderer-free contract tests for `backend/Highscore.hx` — the save-game
 * score store. The module only needs a `FlxG.save` stand-in, a path formatter
 * and the difficulty table, so it runs on the interpreter.
 * Run with:
 *
 *     bash tests/haxe/run-highscore.sh
 */
class HighscoreSpec
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

	/** Fresh maps and a fresh save stand-in so each test starts from zero. */
	static function reset():Void
	{
		Highscore.weekScores = new Map();
		Highscore.songScores = new Map();
		Highscore.songRating = new Map();
		FlxG.save.data = {};
		FlxG.save.flushCount = 0;
	}

	/** Runs every spec section in order and resets the shared state afterwards. */
	static function main():Void
	{
		formatSong();
		floorDecimal();
		saveScoreOnlyIncreases();
		saveScoreRatingRules();
		saveWeekScoreOnlyIncreases();
		gettersSeedZero();
		resets();
		load();

		Sys.println('HighscoreSpec: PASS');
	}

	/** Covers format song. */
	static function formatSong():Void
	{
		reset();
		equal(Highscore.formatSong('Bopeebo', 1), 'bopeebo', 'default difficulty carries no suffix');
		equal(Highscore.formatSong('Bopeebo', 0), 'bopeebo-easy', 'easy suffix');
		equal(Highscore.formatSong('Bopeebo', 2), 'bopeebo-hard', 'hard suffix');
		equal(Highscore.formatSong('My Song', 2), 'my-song-hard', 'spaces and case are normalized');
	}

	/** Covers floor decimal. */
	static function floorDecimal():Void
	{
		reset();
		near(Highscore.floorDecimal(2.675, 2), 2.67, 'truncates instead of rounding');
		near(Highscore.floorDecimal(3.14159, 3), 3.141, 'three decimals truncated');
		near(Highscore.floorDecimal(9.99, 1), 9.9, 'one decimal truncated');
		near(Highscore.floorDecimal(7.8, 0), 7, 'zero decimals floors');
		near(Highscore.floorDecimal(7.8, -2), 7, 'negative decimals floors');
		near(Highscore.floorDecimal(-1.5, 0), -2, 'negative values floor away from zero');
	}

	/** Covers save score only increases. */
	static function saveScoreOnlyIncreases():Void
	{
		reset();
		Highscore.saveScore('Bopeebo', 1000, 1);
		equal(Highscore.songScores.get('bopeebo'), 1000, 'first score stored');
		equal(FlxG.save.flushCount, 1, 'first score flushes once');

		Highscore.saveScore('Bopeebo', 400, 1);
		equal(Highscore.songScores.get('bopeebo'), 1000, 'lower score does not overwrite');
		equal(FlxG.save.flushCount, 1, 'rejected score does not flush');

		Highscore.saveScore('Bopeebo', 1000, 1);
		equal(Highscore.songScores.get('bopeebo'), 1000, 'equal score does not overwrite');
		equal(FlxG.save.flushCount, 1, 'equal score does not flush');

		Highscore.saveScore('Bopeebo', 1500, 1);
		equal(Highscore.songScores.get('bopeebo'), 1500, 'higher score overwrites');
		equal(FlxG.save.flushCount, 2, 'higher score flushes');

		// Difficulties are independent buckets.
		Highscore.saveScore('Bopeebo', 10, 0);
		equal(Highscore.songScores.get('bopeebo-easy'), 10, 'easy is a separate entry');
		equal(Highscore.songScores.get('bopeebo'), 1500, 'normal entry untouched');
	}

	/** Covers save score rating rules. */
	static function saveScoreRatingRules():Void
	{
		reset();
		Highscore.saveScore('Bopeebo', 1000, 1, 92.5);
		near(Highscore.songRating.get('bopeebo'), 92.5, 'rating stored with the first score');

		// A higher score updates a supplied rating; re-saves of the same or
		// lower scores do not, and neither does a higher score with rating -1.
		Highscore.saveScore('Bopeebo', 1200, 1, -1);
		near(Highscore.songRating.get('bopeebo'), 92.5, 'rating -1 leaves the stored rating alone');

		Highscore.saveScore('Bopeebo', 1500, 1, 97.25);
		near(Highscore.songRating.get('bopeebo'), 97.25, 'higher score updates the rating');

		Highscore.saveScore('Bopeebo', 1500, 1, 50);
		near(Highscore.songRating.get('bopeebo'), 97.25, 'equal score does not update the rating');

		Highscore.saveScore('Bopeebo', 1000, 1, 50);
		near(Highscore.songRating.get('bopeebo'), 97.25, 'lower score does not update the rating');
	}

	/** Covers save week score only increases. */
	static function saveWeekScoreOnlyIncreases():Void
	{
		reset();
		Highscore.saveWeekScore('Week 1', 5000, 1);
		equal(Highscore.weekScores.get('week-1'), 5000, 'first week score stored');
		equal(FlxG.save.flushCount, 1, 'first week score flushes');

		Highscore.saveWeekScore('Week 1', 3000, 1);
		equal(Highscore.weekScores.get('week-1'), 5000, 'lower week score does not overwrite');

		Highscore.saveWeekScore('Week 1', 7000, 1);
		equal(Highscore.weekScores.get('week-1'), 7000, 'higher week score overwrites');
		equal(FlxG.save.flushCount, 2, 'higher week score flushes');
	}

	/** Covers getters seed zero. */
	static function gettersSeedZero():Void
	{
		reset();
		equal(Highscore.getScore('Unknown', 1), 0, 'unknown song reads as zero');
		check(Highscore.songScores.exists('unknown'), 'reading an unknown song seeds a zero entry');
		near(Highscore.getRating('Unknown', 1), 0, 'unknown rating reads as zero');
		check(Highscore.songRating.exists('unknown'), 'reading an unknown rating seeds a zero entry');
		equal(Highscore.getWeekScore('Unknown Week', 1), 0, 'unknown week reads as zero');
		check(Highscore.weekScores.exists('unknown-week'), 'reading an unknown week seeds a zero entry');
	}

	/** Covers resets. */
	static function resets():Void
	{
		reset();
		Highscore.saveScore('Bopeebo', 1000, 1, 88);
		Highscore.resetSong('Bopeebo', 1);
		equal(Highscore.songScores.get('bopeebo'), 0, 'resetSong zeroes the score');
		near(Highscore.songRating.get('bopeebo'), 0, 'resetSong zeroes the rating');

		Highscore.saveWeekScore('Week 1', 5000, 1);
		Highscore.resetWeek('Week 1', 1);
		equal(Highscore.weekScores.get('week-1'), 0, 'resetWeek zeroes the week score');

		// Resetting one difficulty leaves the others alone.
		Highscore.saveScore('Bopeebo', 300, 0);
		Highscore.resetSong('Bopeebo', 0);
		equal(Highscore.songScores.get('bopeebo'), 0, 'normal stayed reset from earlier test');
		equal(Highscore.songScores.get('bopeebo-easy'), 0, 'easy reset independently');
	}

	/** Covers load. */
	static function load():Void
	{
		reset();
		var weeks = new Map<String, Int>();
		weeks.set('week-1', 12345);
		var songs = new Map<String, Int>();
		songs.set('bopeebo', 6789);
		var ratings = new Map<String, Float>();
		ratings.set('bopeebo', 95.5);
		FlxG.save.data.weekScores = weeks;
		FlxG.save.data.songScores = songs;
		FlxG.save.data.songRating = ratings;

		Highscore.load();
		equal(Highscore.weekScores.get('week-1'), 12345, 'week scores load from the save');
		equal(Highscore.songScores.get('bopeebo'), 6789, 'song scores load from the save');
		near(Highscore.songRating.get('bopeebo'), 95.5, 'ratings load from the save');

		// A save without any of the three fields keeps the current (empty) maps.
		reset();
		Highscore.load();
		equal(Highscore.weekScores.keys().hasNext(), false, 'missing save data keeps the empty map');
	}
}
