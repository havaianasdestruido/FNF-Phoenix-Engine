package options;

import shaders.RainShader.Light;

import backend.ClientPrefs;
import backend.LowMemory;
import backend.MemoryProfiles;
import backend.VLog;
import objects.Note;
import objects.Prompt;

class OptimizationSubState extends BaseOptionsMenu
{
	public function new()
	{
		title = 'Optimization';
		rpcTitle = 'Optimization Settings Menu'; //for Discord Rich Presence

		// A profile is a bundle of the options in this list plus a cleanup
		// schedule, so it goes first: it explains what it forces below.
		var option:Option = new Option('Memory Profile',
			'A single switch for devices short on RAM, in the spirit of\n'
			+ 'Codename Engine\'s low memory mode. It bundles a few appearance\n'
			+ 'options and schedules asset cleanups; the preferences it manages\n'
			+ 'are forced while it is on, and your own values come back when\n'
			+ 'you choose Off again.\n\n'
			+ 'Off:     nothing is changed.\n'
			+ 'Low:     fewer splashes, no moving menu checkerboard, unused\n'
			+ '         assets freed after every song.\n'
			+ 'Extreme: also Low Quality stages, no shaders, AA, splashes or\n'
			+ '         camera bops, and a deep release after each song.',
			'memoryProfile',
			'string',
			MemoryProfiles.OFF,
			MemoryProfiles.NAMES);
		option.onChange = function() {
			// Saved by OptionsState on exit like the rest of the list; the trim
			// inside setProfile is what makes the change felt immediately.
			LowMemory.setProfile(ClientPrefs.memoryProfile, false);
		};
		addOption(option);

		option = new Option('Adaptive Performance',
			'If FPS stays below the target for 3 seconds,\n'
			+ 'turns off splashes, then ratings, then camera bops this song.\n'
			+ 'Requests GC where supported (even if auto-GC is off);\n'
			+ 'may hitch. Your saved preferences are unchanged.',
			'adaptivePerformance', 'bool', false);
		addOption(option);

		option = new Option('Free Memory Now',
			'Releases cached images and sounds that nothing is using right now.\n'
			+ 'Handy before a heavy song; assets are simply reloaded if you go back.\n'
			+ 'Anything still on screen is left alone.',
			'freeMemoryNow',
			'link',
			false);
		option.onChange = freeMemoryNow;
		addOption(option);

		//I'd suggest using "Chars & BG" as an example for making your own option since it is the simplest here
		var option:Option = new Option('Chars & BG', //Name
			'If unchecked, gameplay will only show the HUD.', //Description
			'charsAndBG', //Save data variable name
			'bool', //Variable type
			true); //Default value
		addOption(option);

		var option:Option = new Option('Enable GC',
			"If checked, then the game will be allowed to garbage collect, reducing RAM usage I suppose.\nIf you experience memory leaks, turn this on, and\nif you experience lag with it on then turn it off.",
			'enableGC',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Light Opponent Strums',
			"If this is unchecked, the Opponent strums won't light up when the Opponent hits a note.",
			'opponentLightStrum',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Light Botplay Strums',
			"If this is unchecked, the Player strums won't light when Botplay is active.",
			'botLightStrum',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Light Player Strums',
			"If this is unchecked, then uh.. the player strums won't light up.\nit's as simple as that.",
			'playerLightStrum',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Ratings',
			"If unchecked, the game will not show a rating sprite when hitting a note.",
			'ratingPopups',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show Combo Numbers',
			"If unchecked, the game will not show combo numbers when hitting a note.",
			'comboPopups',
			'bool',
			true);
		addOption(option);

		var option:Option = new Option('Show MS Popup',
			"If checked, hitting a note will also show how late/early you hit it.",
			'showMS',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Early/Late Ratings',
			"If checked, the rating popup also says whether you hit the note Early or Late.\nHits close enough to 0 ms show no label.",
			'earlyLateRatings',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Early/Late Dead Zone',
			"How much of the hit window, around 0 ms, counts as perfectly on time.\nInside it no Early/Late label is shown.\n0.1 is Mic'd Up!'s default.",
			'earlyLateDeadzone',
			'percent',
			0.1);
		addOption(option);
		option.scrollSpeed = 0.4;
		option.minValue = 0;
		option.maxValue = 0.45;
		option.changeValue = 0.01;
		option.decimals = 2;

		var option:Option = new Option('Disable onSpawnNote Lua Calls',
			"If checked, the game will not call onSpawnNote when a note is spawned.\nIf you have a script that uses that, maybe leave it on.",
			'noSpawnFunc',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Disable Hit Lua Calls',
			"If checked, the game will not call note hit functions when a note is hit.",
			'noHitFuncs',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Disable Skip Lua Calls',
			"If checked, the game will not call note hit functions for skipped notes.",
			'noSkipFuncs',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Even LESS Botplay Lag',
			"Reduce Botplay lag even further.",
			'lessBotLag',
			'bool',
			false);
		addOption(option);

		var option:Option = new Option('Max Rendered Notes: ',
			"The max amount of notes that the game can render onscreen.\nTo remove this limit, set it to 0.",
			'maxNotes',
			'int',
			0);
		addOption(option);

		option.scrollSpeed = 2000;
		option.minValue = 0;
		option.maxValue = 99999;
		option.displayFormat = '%v Notes';

		cameras = [FlxG.cameras.list[FlxG.cameras.list.length-1]];

		addBackupOptions();

		super();
	}

	/**
	 * Options -> Optimization -> "Free Memory Now".
	 *
	 * Uses the same shallow trim as a profile's idle pass, so a player who does
	 * not want a whole profile can still reclaim RAM on demand without risking
	 * the menu's own generated bitmaps. The heap numbers are best-effort:
	 * platforms that cannot report them show a generic message.
	 */
	function freeMemoryNow():Void
	{
		final before:Float = VLog.heapUsedBytes();
		LowMemory.trim(false);
		final after:Float = VLog.heapUsedBytes();

		var message:String = 'Cached assets have been released.';
		if (before > 0 && after > 0)
		{
			message = 'Heap: ' + VLog.formatBytes(before) + ' -> ' + VLog.formatBytes(after) + '\n';
			message += (before > after
				? 'Freed ' + VLog.formatBytes(before - after) + '.'
				: 'Nothing else could be released right now.');
		}

		openSubState(new Prompt(message, 0, null, null, false, 'OK', 'Close'));
	}
}
