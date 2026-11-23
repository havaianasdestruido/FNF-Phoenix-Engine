import backend.ClientPrefs;
import backend.CoolUtil;
import backend.Conductor;
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import lime.app.Application;
import lime.system.System;
import lime.utils.Assets;
import openfl.display.BitmapData;
import play.PlayState;
import shaders.RGBPalette.RGBShaderReference;
import objects.Character;
import objects.Note;
import data.Song.SwagSong;

/**
 * Renderer-free contract tests for `backend/CoolUtil.hx` — the bag of static
 * helpers almost every part of the engine touches: formatting (time, compact
 * numbers, padding), quant-based note colours, the dominant-colour probe, the
 * file/alert/browser shims and the tiny index/math helpers.
 *
 * The production module runs on the Haxe interpreter with the stubs under
 * `tests/haxe/stubs/cool-util/` (scriptable Application/Window, BitmapData,
 * FlxColor, scripted Assets, no-op WindowMode) plus the shared Flixel-free
 * stubs in `tests/haxe/stubs/`. `quantize()` is intentionally not asserted:
 * under `--interp` `Math.fround` behaves like round-half-up to an integer,
 * which makes the function's behaviour target-dependent. Run with:
 *
 *     bash tests/haxe/run-cool-util.sh
 */
class CoolUtilSpec
{
	/** Asserts reference/value equality with a labelled failure message. */
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	/** Asserts a boolean condition with a labelled failure message. */
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	/** Asserts array contents element-by-element. */
	static function equalArray<T>(actual:Array<T>, expected:Array<T>, label:String):Void
	{
		if (actual == null) throw '$label: expected $expected, got null';
		if (actual.length != expected.length)
			throw '$label: expected [${expected.join(', ')}], got [${actual.join(', ')}]';
		for (i in 0...actual.length)
			if (actual[i] != expected[i])
				throw '$label: index $i expected ${expected[i]}, got ${actual[i]}';
	}

	/** Restores the ClientPrefs gates CoolUtil reads in checkNoteQuant. */
	static function resetNoteColorPrefs():Void
	{
		ClientPrefs.noteColorStyle = 'RGB';
		ClientPrefs.showNotes = true;
		ClientPrefs.enableColorShader = true;
	}

	/** Restores the Conductor statics checkNoteQuant binary-searches. */
	static function resetConductor():Void
	{
		Conductor.bpm = 100;
		Conductor.bpmChangeMap = [];
	}

	/** Restores the stage metadata and captured openURL calls used by getSavePath/browserLoad. */
	static function resetStage():Void
	{
		FlxG.reset();
	}

	/** Restores the scripted Assets stand-in (missing asset by default). */
	static function resetAssets():Void
	{
		Assets.reset();
	}

	/** Restores the difficulty list and the story difficulty index. */
	static function resetDifficulties():Void
	{
		CoolUtil.difficulties = [];
		PlayState.storyDifficulty = 1;
	}

	/** Restores the scripted platform label. */
	static function resetPlatform():Void
	{
		System.platformLabel = 'Linux';
	}

	/** Drops the alerts captured through the Application/Window stub. */
	static function resetAlerts():Void
	{
		Application.current.window.alerts = [];
	}

	/** Wraps an Int index into [0, length), including negatives and non-positive lengths. */
	static function clampIndexWrapping():Void
	{
		equal(CoolUtil.clampIndex(0, 3), 0, 'zero index stays zero');
		equal(CoolUtil.clampIndex(5, 3), 2, 'positive index wraps modulo length');
		equal(CoolUtil.clampIndex(3, 3), 0, 'index == length wraps to zero');
		equal(CoolUtil.clampIndex(-1, 3), 2, 'negative index wraps from the end');
		equal(CoolUtil.clampIndex(-7, 3), 2, 'magnitude beyond one turn still wraps');
		equal(CoolUtil.clampIndex(42, 0), 0, 'zero length yields 0');
		equal(CoolUtil.clampIndex(-42, -1), 0, 'negative length yields 0');
	}

	/** Formats elapsed milliseconds as m:ss with hour/day/week branches and sub-second precision. */
	static function formatTimeFormatting():Void
	{
		equal(CoolUtil.formatTime(0), '0:00', 'zero formats as 0:00');
		equal(CoolUtil.formatTime(1000), '0:01', 'one second');
		equal(CoolUtil.formatTime(61000), '1:01', 'minute and second');
		equal(CoolUtil.formatTime(3600000), '1:00:00', 'whole hour gets the hh: branch');
		equal(CoolUtil.formatTime(3661000), '1:01:01', 'hour minute second');
		equal(CoolUtil.formatTime(86400000), '1d 0h 0m 0s', 'one day uses the d/h/m/s layout');
		equal(CoolUtil.formatTime(90061000), '1d 1h 1m 1s', 'day hour minute second');
		equal(CoolUtil.formatTime(604800000), '1w 0d 0h 0m 0s', 'one week uses the w/d/h/m/s layout');
		equal(CoolUtil.formatTime(61500, 1), '1:01.5', 'tenth of a second precision');
		equal(CoolUtil.formatTime(61250, 2), '1:01.25', 'hundredth of a second precision');
		equal(CoolUtil.formatTime(61500, 2), '1:01.50', 'hundredths keep one trailing zero');
		equal(CoolUtil.formatTime(61500, 3), '1:01.500', 'thousandths keep two trailing zeros');
		equal(CoolUtil.formatTime(61000, 1), '1:01.0', 'exact second still prints the precision digit');
	}

	/** Formats remaining milliseconds as a countdown, mirroring formatTime. */
	static function getSongDurationFormatting():Void
	{
		equal(CoolUtil.getSongDuration(0, 61000), '1:01', 'remaining minute formats as m:ss');
		equal(CoolUtil.getSongDuration(60000, 61000), '0:01', 'one second remaining');
		equal(CoolUtil.getSongDuration(0, 3723000), '1:02:03', 'over an hour includes the hour part');
		equal(CoolUtil.getSongDuration(0, 3600000), '1:00:00', 'exact hour');
		equal(CoolUtil.getSongDuration(0, 61500, 1), '1:01.5', 'tenth precision');
		equal(CoolUtil.getSongDuration(0, 61500, 2), '1:01.50', 'hundredth precision');
	}

	/**
	 * Compact magnitude formatting, including the sub-1000 band. Sub-1000 values
	 * used to index the suffix tables at -1 and crash with a null access; they
	 * now return the plain floored value.
	 */
	static function formatCompactNumberMagnitudes():Void
	{
		equal(CoolUtil.formatCompactNumber(0), '0', 'zero is "0"');
		equal(CoolUtil.formatCompactNumber(0.0001), '0', 'tiny value collapses to "0"');
		equal(CoolUtil.formatCompactNumber(0.5), '0.5', 'sub-unit values keep their decimals');
		equal(CoolUtil.formatCompactNumber(500), '500', 'hundreds return the plain value');
		equal(CoolUtil.formatCompactNumber(999), '999', 'just below a thousand');
		equal(CoolUtil.formatCompactNumber(-0.5), '-0.5', 'small negatives return the plain value');
		equal(CoolUtil.formatCompactNumber(-1500), '-1500', 'negatives return the plain value');
		equal(CoolUtil.formatCompactNumber(1000), '1 thousand', 'exactly one thousand');
		equal(CoolUtil.formatCompactNumber(1500), '1.5 thousand', 'one and a half thousand');
		equal(CoolUtil.formatCompactNumber(999499), '999.49 thousand', 'floors to two decimals');
		equal(CoolUtil.formatCompactNumber(1000000), '1 million', 'one million');
		equal(CoolUtil.formatCompactNumber(2500000), '2.5 million', 'two point five million');
		equal(CoolUtil.formatCompactNumber(1000000000), '1 billion', 'one billion');
		equal(CoolUtil.formatCompactNumber(1000000000000), '1 trillion', 'one trillion');
	}

	/** Pads integers with leading zeros; longer inputs pass through untouched. */
	static function zeroFillPadding():Void
	{
		equal(CoolUtil.zeroFill(7, 3), '007', 'short value gets padded');
		equal(CoolUtil.zeroFill(42, 3), '042', 'pad to three digits');
		equal(CoolUtil.zeroFill(0, 2), '00', 'zero gets padded');
		equal(CoolUtil.zeroFill(1234, 3), '1234', 'value longer than digits passes through');
		equal(CoolUtil.zeroFill(123, 3), '123', 'exact width passes through');
	}

	/** Floors to a number of decimals, rounding towards -inf rather than truncating. */
	static function floorDecimalRounding():Void
	{
		equal(CoolUtil.floorDecimal(3.14159, 2), 3.14, 'keeps two decimals');
		equal(CoolUtil.floorDecimal(3.9, 0), 3.0, 'zero decimals floor the value');
		equal(CoolUtil.floorDecimal(9.999, 2), 9.99, 'rounds down, never up');
		equal(CoolUtil.floorDecimal(-3.14159, 2), -3.15, 'negatives floor towards -inf');
	}

	/** Returns [min, max] regardless of argument order, including negatives. */
	static function getMinAndMaxOrdering():Void
	{
		equalArray(CoolUtil.getMinAndMax(7, 3), [3.0, 7.0], 'swapped order still yields [min, max]');
		equalArray(CoolUtil.getMinAndMax(-2, 5), [-2.0, 5.0], 'negative and positive pair');
		equalArray(CoolUtil.getMinAndMax(4, 4), [4.0, 4.0], 'equal values produce equal bounds');
	}

	/** clamp/boundTo pin a value into the inclusive range. */
	static function clampBoundToRange():Void
	{
		equal(CoolUtil.clamp(5, 0, 10), 5.0, 'inside stays inside');
		equal(CoolUtil.clamp(-3, 0, 10), 0.0, 'below range pins to min');
		equal(CoolUtil.clamp(99, 0, 10), 10.0, 'above range pins to max');
		equal(CoolUtil.boundTo(99, 0, 10), 10.0, 'boundTo mirrors clamp');
		equal(CoolUtil.boundTo(-1, 0, 10), 0.0, 'boundTo pins below range');
	}

	/** Builds an ascending array [min, max); min defaults to 0. */
	static function numberArrayRange():Void
	{
		equalArray(CoolUtil.numberArray(4, 1), [1, 2, 3], 'explicit min starts there');
		equalArray(CoolUtil.numberArray(3), [0, 1, 2], 'default min is zero');
		equalArray(CoolUtil.numberArray(0), [], 'empty range yields an empty array');
	}

	/** Splits a trimmed blob into trimmed lines, keeping interior empty lines. */
	static function listFromStringSplitting():Void
	{
		equalArray(CoolUtil.listFromString('  alpha\n beta \n\ngamma'),
			['alpha', 'beta', '', 'gamma'], 'lines are trimmed, empties preserved, trailing newline ignored');
		equalArray(CoolUtil.listFromString('single'), ['single'], 'a lone line splits once');
	}

	/** Parses colour strings: hex digits, 0x prefixes, whitespace noise and junk fallbacks. */
	static function colorFromStringParsing():Void
	{
		equal(CoolUtil.colorFromString('#12AB34'), 0xFF12AB34, '#RRGGBB parses opaque');
		equal(CoolUtil.colorFromString('12AB34'), 0xFF12AB34, 'bare hex falls back through fromString("#...")');
		equal(CoolUtil.colorFromString('0xFF8800'), 0xFFFF8800, '0x prefix is stripped to the last 6 digits');
		equal(CoolUtil.colorFromString('0xff8800'), 0xFFFF8800, '0x prefix is case-insensitive');
		equal(CoolUtil.colorFromString('  #FFFFFF\n'), 0xFFFFFFFF, 'whitespace and newlines are hidden before parsing');
		equal(CoolUtil.colorFromString('red'), FlxColor.RED, 'named colours pass through fromString');
		equal(CoolUtil.colorFromString('definitely not a color'), FlxColor.WHITE, 'unparseable input falls back to WHITE');
	}

	/** Reads health colours: null characters fall back to red, characters supply their own. */
	static function getHealthColorsNullAndCharacter():Void
	{
		equalArray(CoolUtil.getHealthColors(null), [255, 0, 0], 'null character falls back to red');
		var character = new Character();
		equalArray(CoolUtil.getHealthColors(character), character.healthColorArray, 'character supplies its healthColorArray');
	}

	/** Delegates to PhoenixVersion.isNewer for release ordering. */
	static function isVersionNewerDelegation():Void
	{
		check(CoolUtil.isVersionNewer('1.2.0', '1.1.0'), 'newer patch wins');
		check(!CoolUtil.isVersionNewer('1.1.0', '1.1.0'), 'equal versions are not newer');
		check(!CoolUtil.isVersionNewer('1.0.0', '1.1.0'), 'older version is not newer');
		check(!CoolUtil.isVersionNewer('junk', '1.0.0'), 'unparseable candidate is not newer');
	}

	/** Difficulty file paths use '-suffix' unless the difficulty is the default (empty suffix). */
	static function difficultyHelpers():Void
	{
		resetDifficulties();
		CoolUtil.difficulties = ['Easy', 'Normal', 'Hard'];
		CoolUtil.defaultDifficulty = 'Normal';

		PlayState.storyDifficulty = 0;
		equal(CoolUtil.getDifficultyFilePath(), '-easy', 'non-default difficulty gets a dash suffix');

		PlayState.storyDifficulty = 1;
		equal(CoolUtil.getDifficultyFilePath(), '', 'default difficulty yields an empty path');
		equal(CoolUtil.difficultyString(), 'NORMAL', 'difficulty string uppercases the name');

		resetDifficulties();
	}

	/** Counts notes: both sides, or per-side with the mustHitSection routing rules. */
	static function getNoteAmountCounting():Void
	{
		var song:SwagSong = {
			bpm: 120,
			notes: [
				{sectionBeats: 4, bpm: 120, changeBPM: false, mustHitSection: true,
					sectionNotes: [[0, 0, 0], [100, 5, 0], [200, 2, 0], [300, 7, 0]]},
				{sectionBeats: 4, bpm: 120, changeBPM: false, mustHitSection: false,
					sectionNotes: [[0, 1, 0], [100, 6, 0]]}
			]
		};
		equal(CoolUtil.getNoteAmount(song), 6, 'both sides counts every note');
		equal(CoolUtil.getNoteAmount(song, false, false), 3, 'player side routes lanes 0-3 to the hit side');
		equal(CoolUtil.getNoteAmount(song, false, true), 3, 'opponent side routes the mirrored lanes');
	}

	/**
	 * Quant colour selection: with the 'Quant-Based' style, showNotes and the
	 * colour shader enabled, the helper overwrites the shader channels with the
	 * palette entry for the detected quant subdivision. Anything else leaves
	 * the shader untouched.
	 */
	static function checkNoteQuantSelection():Void
	{
		resetNoteColorPrefs();
		resetConductor();

		// Style gate: the default 'RGB' style must not touch the shader.
		var gated = new RGBShaderReference();
		var gatedR = gated.r;
		var gatedG = gated.g;
		var gatedB = gated.b;
		CoolUtil.checkNoteQuant(new Note(), 600, gated);
		equal(gated.r, gatedR, 'RGB style leaves r untouched');
		equal(gated.g, gatedG, 'RGB style leaves g untouched');
		equal(gated.b, gatedB, 'RGB style leaves b untouched');

		// showNotes gate.
		ClientPrefs.noteColorStyle = 'Quant-Based';
		ClientPrefs.showNotes = false;
		var hidden = new RGBShaderReference();
		var hiddenR = hidden.r;
		CoolUtil.checkNoteQuant(new Note(), 600, hidden);
		equal(hidden.r, hiddenR, 'showNotes=false leaves the shader untouched');
		ClientPrefs.showNotes = true;

		// enableColorShader gate.
		ClientPrefs.enableColorShader = false;
		var disabled = new RGBShaderReference();
		var disabledR = disabled.r;
		CoolUtil.checkNoteQuant(new Note(), 600, disabled);
		equal(disabled.r, disabledR, 'enableColorShader=false leaves the shader untouched');
		ClientPrefs.enableColorShader = true;

		// Subdivision detection with no BPM changes (Conductor.bpm = 100).
		var byTime:Array<{t:Float, index:Int}> = [
			{t: 0, index: 0},   // whole beat
			{t: 600, index: 0}, // one beat at 100 BPM
			{t: 300, index: 1}, // half beat -> 1/8 note
			{t: 150, index: 3}, // quarter beat -> 1/16 note
			{t: 75, index: 5}   // eighth beat -> 1/32 note
		];
		for (entry in byTime)
		{
			var shader = new RGBShaderReference();
			CoolUtil.checkNoteQuant(new Note(), entry.t, shader);
			equal(shader.r, entry.index + 1, 't=${entry.t} sets r for quant ${entry.index}');
			equal(shader.g, (entry.index + 1) * 2, 't=${entry.t} sets g for quant ${entry.index}');
			equal(shader.b, (entry.index + 1) * 3, 't=${entry.t} sets b for quant ${entry.index}');
		}

		// BPM change map: entries before the change use the old tempo.
		Conductor.bpmChangeMap = [
			{stepTime: 0, songTime: 0.0, bpm: 100, stepCrochet: 600.0},
			{stepTime: 192, songTime: 28800.0, bpm: 200, stepCrochet: 300.0}
		];

		var beforeChange = new RGBShaderReference();
		CoolUtil.checkNoteQuant(new Note(), 14475, beforeChange);
		equal(beforeChange.r, 6, 'time before the BPM change uses the base tempo (quant 5)');

		var atChange = new RGBShaderReference();
		CoolUtil.checkNoteQuant(new Note(), 28800, atChange);
		equal(atChange.r, 1, 'exactly at the BPM change quant is 0');

		var afterChange = new RGBShaderReference();
		CoolUtil.checkNoteQuant(new Note(), 28875, afterChange);
		equal(afterChange.r, 4, 'after the BPM change the new tempo applies (quant 3)');

		// null shader must not crash even in Quant-Based mode.
		CoolUtil.checkNoteQuant(new Note(), 600, null);

		resetNoteColorPrefs();
		resetConductor();
	}

	/** Dominant colour: count non-transparent pixels, seeded with BLACK, restore useFramePixels. */
	static function dominantColorCounting():Void
	{
		var sprite = new FlxSprite();
		sprite.frameWidth = 2;
		sprite.frameHeight = 2;
		var bitmap = new BitmapData(2, 2);
		bitmap.setPixel32(0, 0, 0xFFFF0000);
		bitmap.setPixel32(1, 0, 0xFFFF0000);
		bitmap.setPixel32(0, 1, 0xFFFF0000);
		bitmap.setPixel32(1, 1, 0xFF00FF00);
		sprite.framePixels = bitmap;
		sprite.useFramePixels = false;

		equal(CoolUtil.dominantColor(sprite), 0xFFFF0000, 'the majority colour wins');
		equal(sprite.useFramePixels, false, 'useFramePixels is restored after the probe');

		var transparent = new FlxSprite();
		transparent.frameWidth = 2;
		transparent.frameHeight = 2;
		transparent.framePixels = new BitmapData(2, 2); // all pixels are 0 (transparent)
		equal(CoolUtil.dominantColor(transparent), FlxColor.BLACK, 'all-transparent sprites fall back to the seeded BLACK');
	}

	/** coolTextFile reads through the Assets shim and trims/splits lines. */
	static function coolTextFileReading():Void
	{
		resetAssets();
		Assets.scriptedExists = false;
		equalArray(CoolUtil.coolTextFile('mods/missing.txt'), [], 'missing asset yields an empty list');

		Assets.scriptedExists = null;
		Assets.scriptedText = '  alpha\n beta \n\ngamma\n';
		equalArray(CoolUtil.coolTextFile('mods/list.txt'),
			['alpha', 'beta', '', 'gamma'], 'lines are trimmed, empties preserved, trailing newline ignored');

		resetAssets();
	}

	/** coolError (and sendMsgBox via showPopUp) raise alerts through Application.current.window. */
	static function coolErrorAlerts():Void
	{
		resetAlerts();
		CoolUtil.coolError('boom', 'titled');
		equal(Application.current.window.alerts.length, 1, 'coolError raises exactly one alert');
		equal(Application.current.window.alerts[0].title, 'titled', 'alert carries the title');
		equal(Application.current.window.alerts[0].message, 'boom', 'alert carries the message');

		var result = CoolUtil.sendMsgBox('hello', 'greetings');
		check(!result, 'sendMsgBox reports false on non-Windows platforms');
		equal(Application.current.window.alerts.length, 2, 'sendMsgBox raises its alert through showPopUp');
		equal(Application.current.window.alerts[1].title, 'greetings', 'sendMsgBox passes the title');

		resetAlerts();
	}

	/** browserLoad hands the URL to openURL (the non-Linux branch under the interpreter). */
	static function browserLoadOpensURL():Void
	{
		resetStage();
		CoolUtil.browserLoad('https://example.com/docs');
		equalArray(FlxG.openedUrls, ['https://example.com/docs'], 'browserLoad opens the URL through FlxG');
	}

	/** getSavePath joins the company meta with the validated file meta. */
	static function getSavePathFromStageMeta():Void
	{
		resetStage();
		equal(CoolUtil.getSavePath(), 'com.example/My Game', 'joins company meta with validated file meta');

		FlxG.stage.application.meta.values['file'] = 'Cool Game 2';
		equal(CoolUtil.getSavePath(), 'com.example/Cool Game 2', 'file meta changes reflect in the save path');

		resetStage();
	}

	/** setTextBorderFromString maps trimmed lower-case names, unknown ones become NONE. */
	static function setTextBorderFromStringMapsNames():Void
	{
		var text = new FlxText(0, 0, 100, 'border test', 8);

		CoolUtil.setTextBorderFromString(text, 'shadow');
		equal(text.borderStyle, FlxTextBorderStyle.SHADOW, 'shadow maps to SHADOW');

		CoolUtil.setTextBorderFromString(text, 'OUTLINE');
		equal(text.borderStyle, FlxTextBorderStyle.OUTLINE, 'names are case-insensitive');

		CoolUtil.setTextBorderFromString(text, 'outline_fast');
		equal(text.borderStyle, FlxTextBorderStyle.OUTLINE_FAST, 'outline_fast maps to OUTLINE_FAST');

		CoolUtil.setTextBorderFromString(text, 'outlinefast');
		equal(text.borderStyle, FlxTextBorderStyle.OUTLINE_FAST, 'outlinefast alias maps to OUTLINE_FAST');

		CoolUtil.setTextBorderFromString(text, '  Shadow  ');
		equal(text.borderStyle, FlxTextBorderStyle.SHADOW, 'names are trimmed');

		CoolUtil.setTextBorderFromString(text, 'junk');
		equal(text.borderStyle, FlxTextBorderStyle.NONE, 'unknown names fall back to NONE');
	}

	/** hasVersion matches case-insensitively against the platform label. */
	static function hasVersionMatchesPlatformLabel():Void
	{
		resetPlatform();
		System.platformLabel = 'Windows 11';
		check(CoolUtil.hasVersion('windows'), 'windows matches Windows 11');
		check(CoolUtil.hasVersion('WIN'), 'matching is case-insensitive');
		check(!CoolUtil.hasVersion('mac'), 'mac does not match Windows 11');
		resetPlatform();
	}

	/** Runs every spec section in order and resets the shared state afterwards. */
	static function main():Void
	{
		clampIndexWrapping();
		formatTimeFormatting();
		getSongDurationFormatting();
		formatCompactNumberMagnitudes();
		zeroFillPadding();
		floorDecimalRounding();
		getMinAndMaxOrdering();
		clampBoundToRange();
		numberArrayRange();
		listFromStringSplitting();
		colorFromStringParsing();
		getHealthColorsNullAndCharacter();
		isVersionNewerDelegation();
		difficultyHelpers();
		getNoteAmountCounting();
		checkNoteQuantSelection();
		dominantColorCounting();
		coolTextFileReading();
		coolErrorAlerts();
		browserLoadOpensURL();
		getSavePathFromStageMeta();
		setTextBorderFromStringMapsNames();
		hasVersionMatchesPlatformLabel();

		resetNoteColorPrefs();
		resetConductor();
		resetStage();
		resetAssets();
		resetDifficulties();
		resetPlatform();
		resetAlerts();

		trace('CoolUtilSpec: PASS');
	}
}
