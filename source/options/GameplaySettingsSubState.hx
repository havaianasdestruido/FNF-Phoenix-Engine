package options;

import backend.Controls;
import flixel.graphics.FlxGraphic;
import flixel.input.keyboard.FlxKey;

import backend.AccuracyPresets;
import backend.ClientPrefs;
import backend.Conductor; // #43
import backend.GamepadDeadzone;
import objects.Note;
import shaders.CrossFade;

class GameplaySettingsSubState extends BaseOptionsMenu
{
	var accuracyPresetOption:Option;
	var perfectWindowOption:Option;
	var sickWindowOption:Option;
	var goodWindowOption:Option;
	var badWindowOption:Option;
	var safeFramesOption:Option;

	public function new()
	{
		title = 'Gameplay Settings';
		rpcTitle = 'Gameplay Settings Menu'; //for Discord Rich Presence

		var option:Option = new Option('Controller Mode',
			'Check this if you want to play with\na controller instead of using your Keyboard.',
			'controllerMode',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Gamepad Deadzone',
			'Minimum analog stick deflection required before controller movement registers.\nLower values feel more responsive; higher values prevent stick drift.',
			'gamepadDeadzone',
			'percent',
			GamepadDeadzone.DEFAULT);
		option.minValue = GamepadDeadzone.MIN;
		option.maxValue = GamepadDeadzone.MAX;
		option.changeValue = GamepadDeadzone.STEP;
		option.scrollSpeed = 0.4;
		option.decimals = 2;
		option.onChange = ClientPrefs.applyGamepadDeadzone;
		addOption(option);

		// A `link` row: ACCEPT opens the page behind `phoenix://input`.
		var option:Option = new Option('Input Tester',
			'Shows every key, gamepad button and finger the game receives,\n'
			+ 'how many it sees held at once and how far apart presses arrive.\n'
			+ 'Handy to find out if a keyboard or touchscreen drops inputs.',
			'inputTester',
			'link',
			false);
		option.onChange = openInputTester;
		addOption(option);

		//I'd suggest using "Downscroll" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Downscroll', //Name
			'If checked, notes go Down instead of Up, simple enough.', //Description
			'downScroll', //Save data variable name
			'bool', //Variable type
			false); //Default value
		addOption(option);

		var option:Option = new Option('Middlescroll',
			'If checked, your notes get centered.',
			'middleScroll',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Opponent Notes',
			'If unchecked, opponent notes get hidden.',
			'opponentStrums',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Ghost Tapping',
			"If checked, you won't get misses from pressing keys\nwhile there are no notes able to be hit.",
			'ghostTapping',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Auto-Pause if Focus Lost',
			"If unchecked, the game won't pause when your game loses focus.",
			'autoPause',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Complex Accuracy',
			"If checked, accuracy is MS-based instead of rating-based.",
			'complexAccuracy',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Remove Perfect!! Judgement',
			"If checked, removes the Perfect judgement.",
			'noMarvJudge',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Disable Reset Button',
			"If checked, pressing Reset won't do anything.",
			'noReset',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Disable Chart Editor',
			"If checked, disables the Chart Editor. Try opening it with this option enabled and see what happens!",
			'antiCheatEnable',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('More Spammable Inputs',
			'If checked, the input system is more spammable.',
			'ezSpam',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Enable Taunt Key',
			"If checked, pressing the Taunt key will make BF go HEY!!",
			'spaceVPose',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Ghost Tapping Plays Anim',
			"If checked, Ghost Tapping will play BF's animations.",
			'ghostTapAnim',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Enable Miss Sound',
			"If checked, re-enables the miss sound when you miss a note.",
			'missSoundEnabled',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Hitsound Volume',
			'Funny notes does \"Tick!\" when you hit them."',
			'hitsoundVolume',
			'percent',
			0);
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;
		option.onChange = onChangeHitsoundVolume;

		var hitsoundList:Array<String> = Mods.mergeAllTextsNamed('sounds/hitsounds/list.txt');
		if (hitsoundList.length > 0)
		{
			if (!hitsoundList.contains(ClientPrefs.hitsoundType))
				ClientPrefs.hitsoundType = hitsoundList[0];

			var option:Option = new Option('Hitsound:',
				"What type of hitsound would you like?",
				'hitsoundType',
				'string',
				'osu!mania',
				hitsoundList);
			addOption(option);
		}

		var option:Option = new Option('Metronome:',
			'Play a tick on every beat. Count-in limits it to the five lead-in beats;\n'
			+ 'Always keeps it through the song. Uses the game volume, so it is silent when muted.',
			'metronome',
			'string',
			'Off',
			['Off', 'Count-in', 'Always']);
		addOption(option);

		// Global song stem volume overrides: forced on every song, so charts, stages and
		// scripts cannot change them (see play.helpers.PlayStatePlayback).
		var option:Option = new Option('Override Instrumental Volume',
			'If checked, every song plays its instrumental at the volume below,\nno matter what charts, stages or scripts try to do.',
			'overrideInstrumentalVolume',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Instrumental Volume Override',
			'The instrumental volume used for all songs while the override is checked.',
			'instrumentalVolumeOverride',
			'percent',
			1);
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;

		var option:Option = new Option('Override Vocal Volume',
			'If checked, every song plays its vocals (yours and the opponent\'s) at the volume\nbelow, no matter what charts, stages or scripts try to do.',
			'overrideVocalsVolume',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Vocal Volume Override',
			'The vocal volume used for all songs while the override is checked.\nVocals still get muted when you miss a note.',
			'vocalsVolumeOverride',
			'percent',
			1);
		addOption(option);
		option.scrollSpeed = 1.6;
		option.minValue = 0.0;
		option.maxValue = 1;
		option.changeValue = 0.1;
		option.decimals = 1;

		var option:Option = new Option('Rating Offset',
			'Changes how late/early you have to hit for a "Sick!"\nHigher values mean you have to hit later.',
			'ratingOffset',
			'int',
			0);
		option.displayFormat = '%vms';
		option.scrollSpeed = 20;
		option.minValue = -30;
		option.maxValue = 30;
		addOption(option);

		ClientPrefs.accuracyPreset = AccuracyPresets.detect(
			ClientPrefs.perfectWindow,
			ClientPrefs.sickWindow,
			ClientPrefs.goodWindow,
			ClientPrefs.badWindow,
			ClientPrefs.safeFrames
		);
		accuracyPresetOption = new Option('Accuracy Preset:',
			'Applies a full set of hit windows and Safe Frames at once\n(Vanilla / Psych / Kade / ITG), or switches to Custom when edited.',
			'accuracyPreset',
			'string',
			AccuracyPresets.PSYCH,
			AccuracyPresets.NAMES);
		accuracyPresetOption.onChange = onChangeAccuracyPreset;
		addOption(accuracyPresetOption);

		final initialBounds = AccuracyPresets.bounds(
			ClientPrefs.perfectWindow,
			ClientPrefs.sickWindow,
			ClientPrefs.goodWindow,
			ClientPrefs.badWindow
		);

		perfectWindowOption = new Option('Perfect! Hit Window',
			'Changes the amount of time you have\nfor hitting a "Perfect!" in milliseconds.',
			'perfectWindow',
			'float',
			AccuracyPresets.DEFAULT_PERFECT);
		perfectWindowOption.displayFormat = '%vms';
		perfectWindowOption.scrollSpeed = 15;
		perfectWindowOption.changeValue = 0.5;
		perfectWindowOption.decimals = 1;
		perfectWindowOption.minValue = initialBounds.perfectMin;
		perfectWindowOption.maxValue = initialBounds.perfectMax;
		perfectWindowOption.onChange = () -> onTimingWindowEdited(perfectWindowOption, false);
		addOption(perfectWindowOption);

		sickWindowOption = new Option('Sick! Hit Window',
			'Changes the amount of time you have\nfor hitting a "Sick!" in milliseconds.',
			'sickWindow',
			'float',
			AccuracyPresets.DEFAULT_SICK);
		sickWindowOption.displayFormat = '%vms';
		sickWindowOption.scrollSpeed = 15;
		sickWindowOption.changeValue = 0.5;
		sickWindowOption.decimals = 1;
		sickWindowOption.minValue = initialBounds.sickMin;
		sickWindowOption.maxValue = initialBounds.sickMax;
		sickWindowOption.onChange = () -> onTimingWindowEdited(sickWindowOption, false);
		addOption(sickWindowOption);

		goodWindowOption = new Option('Good Hit Window',
			'Changes the amount of time you have\nfor hitting a "Good" in milliseconds.',
			'goodWindow',
			'float',
			AccuracyPresets.DEFAULT_GOOD);
		goodWindowOption.displayFormat = '%vms';
		goodWindowOption.scrollSpeed = 30;
		goodWindowOption.changeValue = 0.5;
		goodWindowOption.decimals = 1;
		goodWindowOption.minValue = initialBounds.goodMin;
		goodWindowOption.maxValue = initialBounds.goodMax;
		goodWindowOption.onChange = () -> onTimingWindowEdited(goodWindowOption, false);
		addOption(goodWindowOption);

		badWindowOption = new Option('Bad Hit Window',
			'Changes the amount of time you have\nfor hitting a "Bad" in milliseconds.',
			'badWindow',
			'float',
			AccuracyPresets.DEFAULT_BAD);
		badWindowOption.displayFormat = '%vms';
		badWindowOption.scrollSpeed = 60;
		badWindowOption.changeValue = 0.5;
		badWindowOption.decimals = 1;
		badWindowOption.minValue = initialBounds.badMin;
		badWindowOption.maxValue = initialBounds.badMax;
		badWindowOption.onChange = () -> onTimingWindowEdited(badWindowOption, false);
		addOption(badWindowOption);

		safeFramesOption = new Option('Safe Frames',
			'Changes how many frames you have for\nhitting a note earlier or late.',
			'safeFrames',
			'float',
			AccuracyPresets.DEFAULT_SAFE_FRAMES);
		safeFramesOption.scrollSpeed = 5;
		safeFramesOption.minValue = 2;
		safeFramesOption.maxValue = 20;
		safeFramesOption.displayFormat = AccuracyPresets.safeFramesDisplayFormat(ClientPrefs.safeFrames);
		safeFramesOption.changeValue = 0.1;
		safeFramesOption.onChange = () -> onTimingWindowEdited(safeFramesOption, true); // #43: safeFrames drives safeZoneOffset/timeScale
		addOption(safeFramesOption);

		var option:Option = new Option('Voiid-Styled Troll Mode',
			"If checked, Troll Mode's speed change will behave like in Voiid Chronicles 1.5/2.0",
			'voiidTrollMode',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Troll Mode Speed Limit:',
			"Do you want a speed limit on Troll Mode? If so, how high do you want it? \n(Low = 1024x, Medium = 2048x, High = 5120x and Highest = 10000x)",
			'trollMaxSpeed',
			'string',
			'Medium',
			['Disabled', 'Lowest', 'Lower', 'Low', 'Medium', 'High', 'Highest']);
		addOption(option);

		// credits to the denpa engine team
		// don't support arcadia though
		var option:Option = new Option('CrossFade Mode:', "What mode should CrossFade be in?", 'crossFadeMode', 'string',
			'Mid-Fight Masses', ['Mid-Fight Masses', 'Static', 'Eccentric', 'Off']);
		addOption(option);

		var option:Option = new Option('BF CrossFade Limit', "Determines the maximium amount of frames of CrossFade the player can have.",
			'boyfriendCrossFadeLimit', 'int', 1);
		addOption(option);
		option.minValue = 1;
		option.maxValue = 10;

		var option:Option = new Option('Opponent CrossFade Limit', "Determines the maximium amount of frames of CrossFade the opponent can have.",
			'crossFadeLimit', 'int', 4);
		addOption(option);
		option.minValue = 1;
		option.maxValue = 10;

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];

		addBackupOptions();

		super();
	}

	function openInputTester():Void
	{
		// A state switch skips OptionsState.closeSubState(), which is where the
		// changes made in this list are normally written to disk.
		ClientPrefs.saveSettings();
		FlxG.switchState(() -> new states.InputTestState(true));
	}

	function onChangeHitsoundVolume()
	{
		if (ClientPrefs.hitsoundType != 'none'){
			final hitSoundString:String = ClientPrefs.hitsoundType;
			FlxG.sound.play(Paths.sound("hitsounds/" + Std.string(hitSoundString).toLowerCase()), ClientPrefs.hitsoundVolume);
		}
	}

	function onChangeAccuracyPreset():Void
	{
		final set = AccuracyPresets.windowsFor(ClientPrefs.accuracyPreset);
		if (set == null)
			return; // Custom keeps the player's current window values untouched.

		ClientPrefs.perfectWindow = set.perfect;
		ClientPrefs.sickWindow = set.sick;
		ClientPrefs.goodWindow = set.good;
		ClientPrefs.badWindow = set.bad;
		ClientPrefs.safeFrames = set.safeFrames;
		refreshTimingBoundsAndLabels();
		Conductor.recalculateTimings();
	}

	function onTimingWindowEdited(editedOption:Option, recalculateSafeZone:Bool):Void
	{
		if (editedOption != null && editedOption != safeFramesOption)
		{
			final raw:Float = editedOption.getValue();
			final minVal:Float = editedOption.minValue != null ? editedOption.minValue : 1.0;
			final maxVal:Float = editedOption.maxValue != null ? editedOption.maxValue : AccuracyPresets.MAX_BAD_WINDOW;
			if (raw < minVal) editedOption.setValue(minVal);
			else if (raw > maxVal) editedOption.setValue(maxVal);
		}

		refreshTimingBoundsAndLabels();

		final detected:String = AccuracyPresets.detect(
			ClientPrefs.perfectWindow,
			ClientPrefs.sickWindow,
			ClientPrefs.goodWindow,
			ClientPrefs.badWindow,
			ClientPrefs.safeFrames
		);
		ClientPrefs.accuracyPreset = detected;
		if (accuracyPresetOption != null && accuracyPresetOption.options != null)
		{
			final idx:Int = accuracyPresetOption.options.indexOf(detected);
			if (idx >= 0) accuracyPresetOption.curOption = idx;
			updateTextFrom(accuracyPresetOption);
		}

		if (recalculateSafeZone)
			Conductor.recalculateTimings();
	}

	function refreshTimingBoundsAndLabels():Void
	{
		final b = AccuracyPresets.bounds(
			ClientPrefs.perfectWindow,
			ClientPrefs.sickWindow,
			ClientPrefs.goodWindow,
			ClientPrefs.badWindow
		);
		if (perfectWindowOption != null)
		{
			perfectWindowOption.minValue = b.perfectMin;
			perfectWindowOption.maxValue = b.perfectMax;
			updateTextFrom(perfectWindowOption);
		}
		if (sickWindowOption != null)
		{
			sickWindowOption.minValue = b.sickMin;
			sickWindowOption.maxValue = b.sickMax;
			updateTextFrom(sickWindowOption);
		}
		if (goodWindowOption != null)
		{
			goodWindowOption.minValue = b.goodMin;
			goodWindowOption.maxValue = b.goodMax;
			updateTextFrom(goodWindowOption);
		}
		if (badWindowOption != null)
		{
			badWindowOption.minValue = b.badMin;
			badWindowOption.maxValue = b.badMax;
			updateTextFrom(badWindowOption);
		}
		if (safeFramesOption != null)
		{
			safeFramesOption.displayFormat = AccuracyPresets.safeFramesDisplayFormat(ClientPrefs.safeFrames);
			updateTextFrom(safeFramesOption);
		}
	}
}
