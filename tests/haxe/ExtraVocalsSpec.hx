import data.ExtraVocals;
import haxe.Json;

/**
 * Dependency-free tests for the chart `extraVocals` parser
 * ("unlimited vocals per strumline", docs/EXTRA_VOCALS.md).
 *
 * Run with tests/haxe/run-extra-vocals.sh. The runner copies
 * source/data/ExtraVocals.hx into an isolated classpath so these assertions
 * exercise the real parser, not a reimplementation.
 */
class ExtraVocalsSpec
{
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	static function main():Void
	{
		testNullAndWrongShapes();
		testStringEntries();
		testObjectEntries();
		testAliases();
		testSideNormalization();
		testInvalidEntriesSkipped();
		testPlayedSide();
		trace('ExtraVocalsSpec passed');
	}

	static function testNullAndWrongShapes():Void
	{
		equal(ExtraVocals.parse(null).length, 0, 'null field yields no stems');
		equal(ExtraVocals.parse('GF').length, 0, 'a bare string field is not a stem list');
		equal(ExtraVocals.parse({file: 'GF'}).length, 0, 'a bare object field is not a stem list');
		equal(ExtraVocals.parse(42).length, 0, 'a number field is not a stem list');
		equal(ExtraVocals.parse([]).length, 0, 'empty list yields no stems');
	}

	static function testStringEntries():Void
	{
		final stems = ExtraVocals.parse(['GF', ' Choir ']);
		equal(stems.length, 2, 'two string entries');
		equal(stems[0].name, 'GF', 'string entry name');
		equal(stems[0].file, 'GF', 'string entry file');
		equal(stems[0].side, ExtraVocals.SIDE_NONE, 'string entries are never auto-muted');
		equal(stems[1].file, 'Choir', 'string entries are trimmed');
	}

	static function testObjectEntries():Void
	{
		final stems = ExtraVocals.parse([
			{name: 'gf', file: 'GF', side: 'none'},
			{name: 'bf-lead', file: 'Player2', side: 'player'},
			{file: 'OpponentBack', side: 'opponent'}
		]);
		equal(stems.length, 3, 'three object entries');
		equal(stems[0].side, ExtraVocals.SIDE_NONE, 'explicit none side');
		equal(stems[1].side, ExtraVocals.SIDE_PLAYER, 'player side');
		equal(stems[1].file, 'Player2', 'player stem file');
		equal(stems[2].name, 'OpponentBack', 'name falls back to the file');
	}

	static function testAliases():Void
	{
		// Codename Engine wording: vocalsSuffix (with its leading dash),
		// strumline, and the numeric strumline type enum.
		final stems = ExtraVocals.parse([
			{vocalsSuffix: '-pico', strumline: 'player'},
			{suffix: 'Mom', type: 0},
			{postfix: 'BfDuet', type: 1},
			{file: 'GF', type: 2}
		]);
		equal(stems.length, 4, 'four aliased entries');
		equal(stems[0].file, 'pico', 'CNE vocalsSuffix leading dash is stripped');
		equal(stems[0].side, ExtraVocals.SIDE_PLAYER, 'strumline alias');
		equal(stems[1].side, ExtraVocals.SIDE_OPPONENT, 'numeric type 0 is the opponent strumline');
		equal(stems[2].side, ExtraVocals.SIDE_PLAYER, 'numeric type 1 is the player strumline');
		equal(stems[3].side, ExtraVocals.SIDE_NONE, 'numeric type 2 (additional) is script-controlled');
	}

	static function testSideNormalization():Void
	{
		equal(ExtraVocals.normalizeSide('player'), ExtraVocals.SIDE_PLAYER, 'player');
		equal(ExtraVocals.normalizeSide(' BF '), ExtraVocals.SIDE_PLAYER, 'bf alias is trimmed');
		equal(ExtraVocals.normalizeSide('OPPONENT'), ExtraVocals.SIDE_OPPONENT, 'case-insensitive opponent');
		equal(ExtraVocals.normalizeSide('dad'), ExtraVocals.SIDE_OPPONENT, 'dad alias');
		equal(ExtraVocals.normalizeSide('gf'), ExtraVocals.SIDE_NONE, 'gf stems are script-controlled');
		equal(ExtraVocals.normalizeSide('bogus'), ExtraVocals.SIDE_NONE, 'unknown sides are safe');
		equal(ExtraVocals.normalizeSide(null), ExtraVocals.SIDE_NONE, 'missing side is safe');
		equal(ExtraVocals.normalizeSide(1), ExtraVocals.SIDE_PLAYER, 'int 1');
		equal(ExtraVocals.normalizeSide(0), ExtraVocals.SIDE_OPPONENT, 'int 0');
		equal(ExtraVocals.normalizeSide(7), ExtraVocals.SIDE_NONE, 'unknown ints are safe');
	}

	static function testInvalidEntriesSkipped():Void
	{
		final stems = ExtraVocals.parse([
			'',
			'   ',
			42,
			null,
			['nested'],
			{},
			{side: 'player'},
			{name: '   ', file: ''},
			{file: '-'},
			{file: 'Valid'}
		]);
		equal(stems.length, 1, 'only the usable entry survives');
		equal(stems[0].file, 'Valid', 'usable entry file');
	}

	static function testPlayedSide():Void
	{
		equal(ExtraVocals.playedSide(false), ExtraVocals.SIDE_PLAYER, 'normal charts play the player side');
		equal(ExtraVocals.playedSide(true), ExtraVocals.SIDE_OPPONENT, 'opponent charts play the opponent side');
	}
}
