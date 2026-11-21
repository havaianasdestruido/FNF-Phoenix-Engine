package options;

import shaders.RainShader.Light;

import backend.BenchmarkKind;
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
			'Off restores choices; Low / Extreme cut effects.\n'
			+ 'EXPERIMENTAL / UNSAFE removes stages and characters.\n'
			+ 'Mods may break; GPU caching can glitch or use more VRAM.\n'
			+ 'Streaming / no preloads may stutter or load slowly.',
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

		// The benchmark suite: one hub for all kinds. Each kind reuses the
		// same fixed-chart, mod-free, botplay contract as the original
		// Device Benchmark — only the note pattern (and for SYNTHETIC the
		// absence of a stage) changes. Above the per-frame toggles, next to
		// Free Memory Now, because it is a one-shot diagnostic.
		var benchHub:Option = new Option('Benchmarks',
			'Open the benchmark suite: visual stress, logic stress,\n'
			+ 'gameplay baseline, plus a ~2 s synthetic CPU test.\n'
			+ 'All are fixed, mod-free and botplayed where applicable;\n'
			+ 'nothing is saved and no F3/F6 keys are needed.',
			'benchmarks',
			'link',
			false);
		benchHub.onChange = openBenchmarks;
		addOption(benchHub);

		// Keep the original single-row entry for muscle-memory and for scripts
		// that drove `deviceBenchmark` by name — it now just opens the same hub
		// with the same confirm, so no save path is broken.
		var benchOption:Option = new Option('Device Benchmark',
			'Runs a fixed, mod-free chart for about 60 seconds,\n'
			+ 'then reports average FPS, 1% low and worst frame,\n'
			+ 'plus your CPU/GPU. Botplay plays the notes itself.\n'
			+ 'Nothing is saved; no mods are loaded; F3/F6 not needed.\n'
			+ 'Tip: Benchmarks (above) has more kinds.',
			'deviceBenchmark',
			'link',
			false);
		benchOption.onChange = deviceBenchmark;
		addOption(benchOption);

		// Direct shortcuts — useful on Android where an extra menu costs taps.
		var visualOpt:Option = new Option('Visual Benchmark',
			'Visual stress: many chords, holds and splashes every 8th.\n'
			+ 'Stresses the renderer/draw-call path; ~60 s, mod-free, botplay.',
			'visualBenchmark',
			'link',
			false);
		visualOpt.onChange = visualBenchmark;
		addOption(visualOpt);

		var logicOpt:Option = new Option('Logic Benchmark',
			'Logic stress: jacks, trills and 16th bursts.\n'
			+ 'Stresses spawning/sorting/update; ~60 s, mod-free, botplay.',
			'logicBenchmark',
			'link',
			false);
		logicOpt.onChange = logicBenchmark;
		addOption(logicOpt);

		var synthOpt:Option = new Option('Synthetic Benchmark',
			'Synthetic CPU test: JSON parse, sort, path/BPM math, alloc/GC (~2 s).\n'
			+ 'No stage or audio; gives a CPU score for bug reports.',
			'syntheticBenchmark',
			'link',
			false);
		synthOpt.onChange = syntheticBenchmark;
		addOption(synthOpt);

		var suiteOpt:Option = new Option('Full Benchmark Suite',
			'Runs the synthetic CPU test now and shows how to complete\n'
			+ 'a full profile with the visual/logic charts (combined report).',
			'benchmarkSuite',
			'link',
			false);
		suiteOpt.onChange = benchmarkSuite;
		addOption(suiteOpt);

		//I'd suggest using \"Chars & BG\" as an example for making your own option since it is the simplest here
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

		var option:Option = new Option('No GC During Rendering',
			'If checked, disables the renderer-related GC fallback used by video rendering.\nThis is set conservatively by first-run setup and remains editable.',
			'noRenderGC',
			'bool',
			false);
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
	 * Options -> Optimization -> \"Free Memory Now\".
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

	/** Opens the hub that lists every benchmark kind. */
	function openBenchmarks():Void
	{
		ClientPrefs.saveSettings();
		FlxG.switchState(() -> new states.BenchmarkMenuState());
	}

	/**
	 * Confirms, then starts the device benchmark (legacy GAMEPLAY).
	 */
	function deviceBenchmark():Void
	{
		openSubState(new Prompt('Run the device benchmark?\\n'
			+ 'A fixed ~60 s chart will play by itself.\\n'
			+ 'Mods are not loaded and nothing is saved.',
			0, startBenchmark, null, false, 'Start', 'Cancel'));
	}

	function startBenchmark():Void
	{
		// A state switch skips OptionsState.closeSubState(), which is where the
		// changes made in this list are normally written to disk.
		ClientPrefs.saveSettings();
		backend.Benchmark.start();
	}

	function visualBenchmark():Void
	{
		openSubState(new Prompt('Run the visual benchmark?\\n'
			+ 'A render-heavy ~60 s chart will play by itself.\\n'
			+ 'Stresses chords/holds/splashes and draw calls.',
			0, function() {
				ClientPrefs.saveSettings();
				backend.Benchmark.startVisual();
			}, null, false, 'Start', 'Cancel'));
	}

	function logicBenchmark():Void
	{
		openSubState(new Prompt('Run the logic benchmark?\\n'
			+ 'A logic-heavy ~60 s chart will play by itself.\\n'
			+ 'Stresses jacks/trills/sorting and the update loop.',
			0, function() {
				ClientPrefs.saveSettings();
				backend.Benchmark.startLogic();
			}, null, false, 'Start', 'Cancel'));
	}

	function syntheticBenchmark():Void
	{
		openSubState(new Prompt('Run the synthetic benchmark?\\n'
			+ 'A ~2 s CPU test with no song or stage.\\n'
			+ 'Measures JSON/sort/math/alloc for a quick CPU score.',
			0, function() {
				ClientPrefs.saveSettings();
				backend.Benchmark.startSynthetic();
			}, null, false, 'Start', 'Cancel'));
	}

	function benchmarkSuite():Void
	{
		openSubState(new Prompt('Run the full benchmark suite?\\n'
			+ 'Synthetic CPU test now, then visual/logic charts\\n'
			+ 'to complete the profile (~2 s + 2×60 s).',
			0, function() {
				ClientPrefs.saveSettings();
				backend.Benchmark.startSuite();
			}, null, false, 'Start', 'Cancel'));
	}
}
