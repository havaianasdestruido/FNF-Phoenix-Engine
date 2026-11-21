package backend;

/**
 * Paths stand-in that resolves vocal stems from an in-memory set of
 * "existing" files, mirroring the real fallback chain: with a difficulty,
 * `Voices-<postfix>-<diff>` wins over `Voices-<postfix>`; a null postfix
 * resolves the shared `Voices` file. Missing keys resolve to null, like
 * returnSound's missing-sentinel path.
 */
class Paths
{
	public static var existing:Map<String, Bool> = new Map();

	public static function voices(song:String, ?difficulty:String = '', ?postfix:String = null, ?stream:Bool = false):Any
	{
		var file:String = 'Voices';
		if (postfix != null) file += '-' + postfix;
		if (difficulty != null && difficulty.length > 0)
		{
			final diffKey:String = '$song/$file-$difficulty';
			if (existing.exists(diffKey)) return diffKey;
		}
		final key:String = '$song/$file';
		return existing.exists(key) ? key : null;
	}
}
