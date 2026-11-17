package backend;

using StringTools;

/**
 * Health-icon style resolution, ported from Mic'd Up!.
 *
 * Mic'd Up! ships whole icon sets in per-style folders
 * (`assets/shared/images/icons/<style>/icon-<char>.png`) and lets the player
 * switch between them from its settings (`iconStyle`). Phoenix keeps the same
 * idea: the flat `images/icons/` folder is the `Default` set, and every extra
 * style is a subfolder named after the style's display name, slugified the
 * same way the rating styles are (`"Mic'd Up"` -> `mic'd-up`).
 *
 * Kept free of Flixel/OpenFL imports so the rules can be asserted directly in
 * `tests/haxe/IconStyleSpec.hx` without a renderer. The actual file-existence
 * check stays in `objects.HealthIcon`, which walks {@link candidates} in order.
 */
class IconStyle
{
	/** Display name of the built-in flat icon set (`images/icons/`). */
	public static inline var DEFAULT_STYLE:String = 'Default';

	/**
	 * Asset folder slug for an icon-style display name.
	 *
	 * @param style display name from the Health Icon Style option
	 *              (e.g. `"Mic'd Up"`, `"Vanilla"`).
	 * @return the subfolder under `images/icons/` holding that style's icons,
	 *         or an empty string for `Default` (and unusable input), which
	 *         means the flat `images/icons/` folder itself.
	 */
	public static function folderFor(style:String):String
	{
		if (style == null || style.length < 1 || style == DEFAULT_STYLE) return '';
		return style.toLowerCase().replace(' ', '-').trim();
	}

	/**
	 * Icon asset names to try for a character, most specific first.
	 *
	 * The active style's folder wins when it has the character, then the flat
	 * icons, then the `face` fallback. Characters a style does not cover (for
	 * example `darnell`, which Mic'd Up! never drew) silently fall back to the
	 * flat set, exactly like a missing rating-style file does.
	 *
	 * @param char  character icon name (e.g. `"bf"`, `"senpai-pixel"`).
	 * @param style display name from the Health Icon Style option.
	 * @return asset names without the `images/` prefix or `.png` suffix,
	 *         ready for `Paths.image` / `Paths.fileExists`.
	 */
	public static function candidates(char:String, style:String):Array<String>
	{
		var list:Array<String> = [];
		final folder:String = folderFor(style);
		if (folder.length > 0)
		{
			list.push('icons/' + folder + '/icon-' + char);
			list.push('icons/' + folder + '/' + char);
		}
		list.push('icons/' + char);
		list.push('icons/icon-' + char);
		list.push('icons/icon-face');
		return list;
	}
}
