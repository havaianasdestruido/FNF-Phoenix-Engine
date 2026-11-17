import backend.IconStyle;

/**
 * Renderer-free contract tests for the Mic'd Up! health-icon style port.
 *
 * `backend/IconStyle.hx` has no Flixel/OpenFL dependency, so the production
 * module is exercised directly in the interpreter. Run with:
 *
 *     bash tests/haxe/run-icon-style.sh
 */
class IconStyleSpec
{
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected "$expected", got "$actual"';
	}

	static function equalList(actual:Array<String>, expected:Array<String>, label:String):Void
	{
		if (actual.length != expected.length)
			throw '$label: expected ${expected.length} candidates $expected, got ${actual.length} $actual';
		for (i in 0...expected.length)
			if (actual[i] != expected[i])
				throw '$label: candidate $i expected "${expected[i]}", got "${actual[i]}"';
	}

	static function main():Void
	{
		testFolderFor();
		testCandidatesDefault();
		testCandidatesStyled();
		testFallbackOrder();

		Sys.println('IconStyleSpec: PASS');
	}

	/** `Default` (and unusable input) means the flat `images/icons/` folder. */
	static function testFolderFor():Void
	{
		equal(IconStyle.folderFor('Default'), '', 'default folder');
		equal(IconStyle.folderFor(''), '', 'empty folder');
		equal(IconStyle.folderFor(null), '', 'null folder');
		// Same slugify rule as the rating styles: lowercase, spaces to dashes.
		equal(IconStyle.folderFor("Mic'd Up"), "mic'd-up", 'micd up folder');
		equal(IconStyle.folderFor('Vanilla'), 'vanilla', 'vanilla folder');
	}

	/** With no style active the lookup is exactly the old flat chain. */
	static function testCandidatesDefault():Void
	{
		equalList(IconStyle.candidates('bf', 'Default'), ['icons/bf', 'icons/icon-bf', 'icons/icon-face'], 'default candidates');
		equalList(IconStyle.candidates('bf', null), ['icons/bf', 'icons/icon-bf', 'icons/icon-face'], 'null style candidates');
	}

	/** A style prepends its folder, `icon-` prefixed name first. */
	static function testCandidatesStyled():Void
	{
		equalList(IconStyle.candidates('bf', "Mic'd Up"),
			["icons/mic'd-up/icon-bf", "icons/mic'd-up/bf", 'icons/bf', 'icons/icon-bf', 'icons/icon-face'],
			"mic'd up candidates");
		equalList(IconStyle.candidates('dad', 'Vanilla'),
			['icons/vanilla/icon-dad', 'icons/vanilla/dad', 'icons/dad', 'icons/icon-dad', 'icons/icon-face'],
			'vanilla candidates');
	}

	/** Characters a style does not cover still resolve through the flat set. */
	static function testFallbackOrder():Void
	{
		final list:Array<String> = IconStyle.candidates('darnell', "Mic'd Up");
		equal(list[list.length - 3], 'icons/darnell', 'flat name before icon- name');
		equal(list[list.length - 2], 'icons/icon-darnell', 'icon- name before face');
		equal(list[list.length - 1], 'icons/icon-face', 'face is last');
	}
}
