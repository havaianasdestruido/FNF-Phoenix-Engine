import backend.ClientPrefs;
import objects.AlphabetFont;
import objects.AlphabetFont.AlphabetFontDef;

/** Contract tests for the font driven alphabet model (source/objects/AlphabetFont.hx).
 * Renderer-free on purpose: the glyphs themselves need OpenFL, the resolution rules do not.
 * Run with: bash tests/haxe/run-alphabet-font.sh
 */
class AlphabetFontSpec
{
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	static function main():Void
	{
		styleResolution();
		fontResolution();
		metrics();
		cacheKeys();
		characterSupport();
		registryConsistency();
		Sys.println('AlphabetFontSpec: PASS');
	}

	/** The style toggle decides between glyphs and the classic spritesheet. */
	static function styleResolution():Void
	{
		equal(AlphabetFont.usesImages(AlphabetFont.STYLE_FONT), false, 'font style');
		equal(AlphabetFont.usesImages(AlphabetFont.STYLE_IMAGE), true, 'image style');
		for (spelling in ['image', 'IMAGE', ' Image ', 'images', 'spritesheet', 'sprite sheet', 'atlas', 'classic', 'legacy'])
			equal(AlphabetFont.usesImages(spelling), true, 'image spelling "$spelling"');
		for (spelling in ['font', 'FONT', ' Font ', 'fonts', 'ttf', 'whatever', ''])
			equal(AlphabetFont.usesImages(spelling), false, 'font fallback "$spelling"');
		check(AlphabetFont.styles().contains(AlphabetFont.STYLE_FONT), 'font style is selectable');
		check(AlphabetFont.styles().contains(AlphabetFont.STYLE_IMAGE), 'image style stays selectable');
		equal(AlphabetFont.DEFAULT_STYLE, AlphabetFont.STYLE_FONT, 'fonts replace the spritesheet by default');

		// A null style falls back to the saved preference, not to a hard coded branch.
		ClientPrefs.alphabetStyle = AlphabetFont.STYLE_IMAGE;
		equal(AlphabetFont.usesImages(null), true, 'null style reads ClientPrefs (image)');
		equal(AlphabetFont.currentUsesImages(), true, 'currentUsesImages reads ClientPrefs');
		ClientPrefs.alphabetStyle = AlphabetFont.STYLE_FONT;
		equal(AlphabetFont.usesImages(null), false, 'null style reads ClientPrefs (font)');
	}

	/** Unknown, cased and file style names all resolve, and always to a usable definition. */
	static function fontResolution():Void
	{
		final vcr:AlphabetFontDef = AlphabetFont.fonts.get('VCR OSD Mono');
		final inconsolata:AlphabetFontDef = AlphabetFont.fonts.get('Inconsolata');
		final tf2:AlphabetFontDef = AlphabetFont.fonts.get('TF2 Build');
		check(tf2 != null, 'TF2 Build is bundled');
		check(vcr != null, 'VCR OSD Mono is bundled');
		check(inconsolata != null, 'Inconsolata is bundled');

		equal(AlphabetFont.resolveFont('VCR OSD Mono').key, vcr.key, 'exact name');
		equal(AlphabetFont.resolveFont('vcr osd mono').key, vcr.key, 'case insensitive name');
		equal(AlphabetFont.resolveFont('  inconsolata ').key, inconsolata.key, 'trimmed name');
		equal(AlphabetFont.resolveFont('vcr').key, vcr.key, 'font key');
		equal(AlphabetFont.resolveFont('vcr.ttf').key, vcr.key, 'asset file');
		equal(AlphabetFont.resolveFont('INCONSOLATA-BOLD.TTF').key, inconsolata.key, 'bold asset file');
		equal(AlphabetFont.resolveFont(' tf2 build ').key, tf2.key, 'TF2 Build name');
		equal(AlphabetFont.resolveFont('TF2BUILD.TTF').key, tf2.key, 'TF2 Build asset file');
		check(AlphabetFont.usesSyntheticBold(tf2, true), 'TF2 Build synthesizes bold');
		equal(AlphabetFont.resolveFont('no such font').key, vcr.key, 'unknown font falls back to the default');
		equal(AlphabetFont.resolveFont('').key, vcr.key, 'empty font falls back');
		equal(AlphabetFont.resolveFont(null).key, vcr.key, 'null font falls back to the default');
		equal(AlphabetFont.DEFAULT_FONT, 'VCR OSD Mono', 'built in VCR is the default font');

		ClientPrefs.alphabetFont = 'Inconsolata';
		equal(AlphabetFont.currentFont().key, inconsolata.key, 'currentFont reads ClientPrefs');
		ClientPrefs.alphabetFont = 'VCR OSD Mono';
		equal(AlphabetFont.currentFont().key, vcr.key, 'currentFont reads ClientPrefs (vcr)');

		final names:Array<String> = AlphabetFont.fontNames();
		equal(names.length, 3, 'three fonts in the options menu');
		equal(names[0], 'VCR OSD Mono', 'VCR listed first');
		equal(names[1], 'Inconsolata', 'Inconsolata listed second');
		equal(names[2], 'TF2 Build', 'TF2 Build listed third');
	}

	/** Sizes and spacing are sane, and fonts without a bold face use synthesized bold. */
	static function metrics():Void
	{
		for (def in AlphabetFont.fonts)
		{
			final regular:Int = AlphabetFont.sizeFor(def, false);
			final bold:Int = AlphabetFont.sizeFor(def, true);
			check(regular > 0, '${def.key} regular size');
			check(bold > regular, '${def.key} bold is bigger than regular');
			check(AlphabetFont.lineHeightFor(def, false) >= regular, '${def.key} rows do not clip regular text');
			check(AlphabetFont.lineHeightFor(def, true) >= bold, '${def.key} rows do not clip bold text');

			// Glyphs are sized to match the spritesheet they replace: ~53px caps, ~68px bold.
			check(def.capHeight > 0.4 && def.capHeight < 1, '${def.key} cap height is a fraction of the em');
			final regularCap:Float = regular * def.capHeight;
			final boldCap:Float = bold * def.capHeight;
			check(regularCap >= 48 && regularCap <= 58, '${def.key} regular caps are spritesheet sized, got $regularCap');
			check(boldCap >= 62 && boldCap <= 74, '${def.key} bold caps are spritesheet sized, got $boldCap');

			final space:Float = AlphabetFont.spaceWidthFor(def, false);
			check(space > 0, '${def.key} space has an advance');
			check(space < regular, '${def.key} space is narrower than the pixel size');

			equal(AlphabetFont.assetFile(def, false), def.regular, '${def.key} regular file');
			if (def.bold == def.regular)
			{
				check(AlphabetFont.usesSyntheticBold(def, true), '${def.key} synthesizes its bold');
				equal(AlphabetFont.assetFile(def, true), def.regular, '${def.key} bold reuses the regular file');
			}
			else
			{
				check(!AlphabetFont.usesSyntheticBold(def, true), '${def.key} has a real bold face');
				equal(AlphabetFont.assetFile(def, true), def.bold, '${def.key} bold file');
			}
			check(!AlphabetFont.usesSyntheticBold(def, false), '${def.key} regular is never synthesized');
		}

		final inconsolata:AlphabetFontDef = AlphabetFont.fonts.get('Inconsolata');
		equal(inconsolata.bold, 'inconsolata-bold.ttf', 'Inconsolata ships a bold face');
		equal(AlphabetFont.fonts.get('VCR OSD Mono').regular, 'vcr.ttf', 'VCR is the bundled vcr.ttf');
	}

	/** Cache keys must collide only for identical glyphs. */
	static function cacheKeys():Void
	{
		final vcr:AlphabetFontDef = AlphabetFont.fonts.get('VCR OSD Mono');
		final inconsolata:AlphabetFontDef = AlphabetFont.fonts.get('Inconsolata');

		equal(AlphabetFont.glyphName('A'), 'u0041', 'glyph name of A');
		equal(AlphabetFont.glyphName('a'), 'u0061', 'glyph name of a');
		equal(AlphabetFont.glyphName(''), 'empty', 'glyph name of an empty string');
		check(AlphabetFont.glyphName('A') != AlphabetFont.glyphName('a'), 'case is preserved in glyph names');

		final base:String = AlphabetFont.cacheKey(vcr, 'A', true);
		equal(base, AlphabetFont.cacheKey(vcr, 'A', true), 'same glyph, same key');
		check(base != AlphabetFont.cacheKey(vcr, 'B', true), 'different character, different key');
		check(base != AlphabetFont.cacheKey(vcr, 'A', false), 'different weight, different key');
		check(base != AlphabetFont.cacheKey(inconsolata, 'A', true), 'different font, different key');
		check(base.indexOf(' ') == -1, 'cache keys carry no spaces');
		check(base.indexOf('vcr') >= 0, 'cache key names the font');
		check(base.indexOf('bold') >= 0, 'cache key names the weight');
		check(AlphabetFont.metricsKey(vcr, true, 'box') != AlphabetFont.metricsKey(vcr, true, 'space'), 'metrics keys stay apart');
	}

	/** The font renderer draws anything printable, unlike the fixed spritesheet. */
	static function characterSupport():Void
	{
		for (char in ['a', 'Z', '7', '#', '@', 'ç', 'Á', 'ñ', '€', '¡', '•'])
			check(AlphabetFont.supports(char), 'supports "$char"');
		for (char in ['', '\n', '\r', '\t', '\x7F', null])
			check(!AlphabetFont.supports(char), 'rejects ${char == null ? "null" : "control character"}');
	}

	/** The registry itself stays consistent: unique keys, listed fonts, real files. */
	static function registryConsistency():Void
	{
		final seen:Map<String, Bool> = new Map();
		var count:Int = 0;
		for (name in AlphabetFont.fonts.keys())
		{
			final def:AlphabetFontDef = AlphabetFont.fonts.get(name);
			count++;
			equal(def.displayName, name, '$name is keyed by its display name');
			check(!seen.exists(def.key), '${def.key} key is unique');
			seen.set(def.key, true);
			check(AlphabetFont.fontOrder.contains(name), '$name is listed in fontOrder');
			check(def.regular.length > 4, '$name has a regular file');
			check(def.bold.length > 4, '$name has a bold file');
			check(def.spaceRatio > 0 && def.spaceRatio <= 1, '$name space ratio is a fraction of the size');
		}
		equal(count, AlphabetFont.fontOrder.length, 'every listed font is registered');
	}
}
