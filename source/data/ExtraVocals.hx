package data;

/**
 * One chart-declared extra vocal stem ("unlimited vocals per strumline").
 *
 * Phoenix always had two fixed vocal tracks (player and opponent). A chart can
 * now declare any number of additional stems, each backed by its own
 * `Voices-<file>` audio file and bound to a strumline side for miss-muting.
 */
typedef ExtraVocalStem =
{
	/** Script/editor identifier. Unique names win: `getExtraVocalVolume('gf')`. */
	var name:String;

	/**
	 * Postfix of the audio file: `file: 'GF'` resolves `Voices-GF.ogg`
	 * (difficulty variants like `Voices-GF-hard.ogg` are tried first, exactly
	 * like the player/opponent stems). An empty file resolves the shared
	 * `Voices.ogg`.
	 */
	var file:String;

	/**
	 * Which strumline the stem follows for muting: `player`, `opponent` or
	 * `none`. Player-side stems mute when the player misses; opponent stems
	 * follow the opponent stem; `none` stems (a third singer, GF duet parts,
	 * choirs) are never auto-muted and are script-controlled.
	 */
	var side:String;
}

/**
 * Parses and normalizes the optional `extraVocals` array of a chart JSON.
 *
 * The parser is deliberately forgiving (charts are hand-edited and come from
 * other engines): entries may be plain strings (`"GF"`) or objects, field
 * aliases cover the Codename Engine wording (`vocalsSuffix`, `strumline`,
 * `type`), and anything unusable is skipped instead of throwing.
 *
 * Pure data module: no Flixel, no engine state, so the Haxe spec can exercise
 * it in isolation.
 */
class ExtraVocals
{
	public static inline var SIDE_PLAYER:String = 'player';
	public static inline var SIDE_OPPONENT:String = 'opponent';
	public static inline var SIDE_NONE:String = 'none';

	/**
	 * Normalizes the raw `extraVocals` JSON value into clean stems.
	 *
	 * - `null`, non-arrays and unusable entries yield nothing (never throws).
	 * - String entries become `{name: value, file: value, side: 'none'}`.
	 * - Object entries read `file`/`postfix`/`suffix`/`vocalsSuffix` for the
	 *   audio postfix (one leading `-` is stripped, so a CNE-style
	 *   `vocalsSuffix: '-bf'` works), `name`/`id` for the identifier (default:
	 *   the file), and `side`/`strumline`/`type` for the side.
	 * - Entries with neither a file nor a name are skipped.
	 */
	public static function parse(raw:Dynamic):Array<ExtraVocalStem>
	{
		final stems:Array<ExtraVocalStem> = [];
		if (!Std.isOfType(raw, Array)) return stems;

		for (entry in (raw:Array<Dynamic>))
		{
			final stem:Null<ExtraVocalStem> = parseEntry(entry);
			if (stem != null) stems.push(stem);
		}
		return stems;
	}

	static function parseEntry(entry:Dynamic):Null<ExtraVocalStem>
	{
		if (Std.isOfType(entry, String))
		{
			final file:String = cleanFile(entry);
			if (file.length < 1) return null;
			return {name: file, file: file, side: SIDE_NONE};
		}
		if (!Reflect.isObject(entry) || Std.isOfType(entry, Array)) return null;

		final file:String = cleanFile(firstString(entry, ['file', 'postfix', 'suffix', 'vocalsSuffix']));
		var name:String = trimString(field(entry, 'name'));
		if (name.length < 1) name = trimString(field(entry, 'id'));
		if (name.length < 1) name = file;
		if (name.length < 1 && file.length < 1) return null;

		final side:String = normalizeSide(firstOf(entry, ['side', 'strumline', 'type']));
		return {name: name, file: file, side: side};
	}

	/**
	 * Maps loose side spellings to `player` / `opponent` / `none`.
	 * Integers follow the CNE strumline type enum (0 = opponent, 1 = player,
	 * anything else = additional → `none`). Unknown values fall back to `none`,
	 * the only side that is never auto-muted by gameplay.
	 */
	public static function normalizeSide(raw:Dynamic):String
	{
		if (Std.isOfType(raw, Int))
		{
			final value:Int = raw;
			return value == 1 ? SIDE_PLAYER : (value == 0 ? SIDE_OPPONENT : SIDE_NONE);
		}
		if (!Std.isOfType(raw, String)) return SIDE_NONE;
		switch (StringTools.trim(cast raw).toLowerCase())
		{
			case 'player' | 'p1' | 'bf' | 'boyfriend' | 'playable':
				return SIDE_PLAYER;
			case 'opponent' | 'p2' | 'dad' | 'enemy' | 'cpu':
				return SIDE_OPPONENT;
			default:
				return SIDE_NONE;
		}
	}

	/** The side whose notes the player must hit in the current run. */
	public static function playedSide(opponentChart:Bool):String
	{
		return opponentChart ? SIDE_OPPONENT : SIDE_PLAYER;
	}

	static function cleanFile(raw:Dynamic):String
	{
		final trimmed:String = trimString(raw);
		// CNE writes vocal suffixes with a leading dash ("Voices-bf" as "-bf");
		// Phoenix postfixes never carry it.
		return StringTools.startsWith(trimmed, '-') ? trimmed.substr(1) : trimmed;
	}

	static function trimString(raw:Dynamic):String
	{
		return Std.isOfType(raw, String) ? StringTools.trim(cast raw) : '';
	}

	static function field(object:Dynamic, name:String):Dynamic
	{
		return object != null ? Reflect.field(object, name) : null;
	}

	static function firstString(object:Dynamic, names:Array<String>):Dynamic
	{
		for (name in names)
		{
			final value:Dynamic = field(object, name);
			if (Std.isOfType(value, String)) return value;
		}
		return null;
	}

	static function firstOf(object:Dynamic, names:Array<String>):Dynamic
	{
		for (name in names)
		{
			final value:Dynamic = field(object, name);
			if (value != null) return value;
		}
		return null;
	}
}
