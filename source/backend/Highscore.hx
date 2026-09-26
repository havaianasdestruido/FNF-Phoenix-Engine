package backend;

import data.Song;

class Highscore
{
	public static var weekScores:Map<String, Int> = new Map();
	public static var songScores:Map<String, Int> = new Map();
	public static var songRating:Map<String, Float> = new Map();

	/**
	 * Executes the `resetSong` operation.
	 * @param song Input value for `song`.
	 * @param diff Input value for `diff`.
	 */
	public static function resetSong(song:String, diff:Int = 0):Void
	{
		var daSong:String = formatSong(song, diff);
		setScore(daSong, 0);
		setRating(daSong, 0);
	}

	/**
	 * Executes the `resetWeek` operation.
	 * @param week Input value for `week`.
	 * @param diff Input value for `diff`.
	 */
	public static function resetWeek(week:String, diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);
		setWeekScore(daWeek, 0);
	}

	/**
	 * Executes the `floorDecimal` operation.
	 * @param value Input value for `value`.
	 * @param decimals Input value for `decimals`.
	 * @return Result produced by `floorDecimal`, when applicable.
	 */
	public static function floorDecimal(value:Float, decimals:Int):Float
	{
		if(decimals < 1)
		{
			return Math.floor(value);
		}

		var tempMult:Float = 1;
		for (i in 0...decimals)
		{
			tempMult *= 10;
		}
		var newValue:Float = Math.floor(value * tempMult);
		return newValue / tempMult;
	}

	/**
	 * Executes the `saveScore` operation.
	 * @param song Input value for `song`.
	 * @param score Input value for `score`.
	 * @param diff Input value for `diff`.
	 * @param rating Input value for `rating`.
	 */
	public static function saveScore(song:String, score:Int = 0, ?diff:Int = 0, ?rating:Float = -1):Void
	{
		var daSong:String = formatSong(song, diff);

		if (songScores.exists(daSong)) {
			if (songScores.get(daSong) < score) {
				setScore(daSong, score);
				if(rating >= 0) setRating(daSong, rating);
			}
		}
		else {
			setScore(daSong, score);
			if(rating >= 0) setRating(daSong, rating);
		}
	}

	/**
	 * Executes the `saveWeekScore` operation.
	 * @param week Input value for `week`.
	 * @param score Input value for `score`.
	 * @param diff Input value for `diff`.
	 */
	public static function saveWeekScore(week:String, score:Int = 0, ?diff:Int = 0):Void
	{
		var daWeek:String = formatSong(week, diff);

		if (weekScores.exists(daWeek))
		{
			if (weekScores.get(daWeek) < score)
				setWeekScore(daWeek, score);
		}
		else
			setWeekScore(daWeek, score);
	}

	/**
	 * YOU SHOULD FORMAT SONG WITH formatSong() BEFORE TOSSING IN SONG VARIABLE
	 */
	static function setScore(song:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songScores.set(song, score);
		FlxG.save.data.songScores = songScores;
		FlxG.save.flush();
	}
	/**
	 * Executes the `setWeekScore` operation.
	 * @param week Input value for `week`.
	 * @param score Input value for `score`.
	 */
	static function setWeekScore(week:String, score:Int):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		weekScores.set(week, score);
		FlxG.save.data.weekScores = weekScores;
		FlxG.save.flush();
	}

	/**
	 * Executes the `setRating` operation.
	 * @param song Input value for `song`.
	 * @param rating Input value for `rating`.
	 */
	static function setRating(song:String, rating:Float):Void
	{
		// Reminder that I don't need to format this song, it should come formatted!
		songRating.set(song, rating);
		FlxG.save.data.songRating = songRating;
		FlxG.save.flush();
	}

	/**
	 * Executes the `formatSong` operation.
	 * @param song Input value for `song`.
	 * @param diff Input value for `diff`.
	 * @return Result produced by `formatSong`, when applicable.
	 */
	public static function formatSong(song:String, diff:Int):String
	{
		return Paths.formatToSongPath(song) + CoolUtil.getDifficultyFilePath(diff);
	}

	/**
	 * Executes the `getScore` operation.
	 * @param song Input value for `song`.
	 * @param diff Input value for `diff`.
	 * @return Result produced by `getScore`, when applicable.
	 */
	public static function getScore(song:String, diff:Int):Int
	{
		var daSong:String = formatSong(song, diff);
		if (!songScores.exists(daSong))
			setScore(daSong, 0);

		return songScores.get(daSong);
	}

	/**
	 * Executes the `getRating` operation.
	 * @param song Input value for `song`.
	 * @param diff Input value for `diff`.
	 * @return Result produced by `getRating`, when applicable.
	 */
	public static function getRating(song:String, diff:Int):Float
	{
		var daSong:String = formatSong(song, diff);
		if (!songRating.exists(daSong))
			setRating(daSong, 0);

		return songRating.get(daSong);
	}

	/**
	 * Executes the `getWeekScore` operation.
	 * @param week Input value for `week`.
	 * @param diff Input value for `diff`.
	 * @return Result produced by `getWeekScore`, when applicable.
	 */
	public static function getWeekScore(week:String, diff:Int):Int
	{
		var daWeek:String = formatSong(week, diff);
		if (!weekScores.exists(daWeek))
			setWeekScore(daWeek, 0);

		return weekScores.get(daWeek);
	}

	/**
	 * Executes the `load` operation.
	 */
	public static function load():Void
	{
		if (FlxG.save.data.weekScores != null)
		{
			weekScores = FlxG.save.data.weekScores;
		}
		if (FlxG.save.data.songScores != null)
		{
			songScores = FlxG.save.data.songScores;
		}
		if (FlxG.save.data.songRating != null)
		{
			songRating = FlxG.save.data.songRating;
		}
	}
}
