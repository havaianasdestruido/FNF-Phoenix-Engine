package states;

import backend.MusicBeatState;
import backend.Paths;
import data.StageData;
import flixel.util.typeLimit.NextState;
import haxe.io.Path;
import play.PlayState;

import flixel.FlxG;
import flixel.FlxBasic;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup;
import flixel.math.FlxMath;
import openfl.utils.AssetType;

#if (cpp && !hl)
import sys.thread.Mutex;
import sys.thread.Thread;
#end

/**
 * Port of Doido Engine's cool looking loading screen (LoadingState + DoidoPreloader).
 *
 * Visuals:
 * - Solid background `0xFFCAFF4D` (lime) covering the stage
 * - Centered `funkay` image at 0.8 scale, gently lerping to 0.75 with a bump on ACCEPT
 * - Bottom pink progress bar `0xFFFF16D2` that lerps to `loadPercent`
 *
 * Logic:
 * - Threads the heavy preload on `cpp` (mirroring Doido's `PRELOAD_SONG` path) and
 *   falls back to a frame-sliced queue on `html5`/other targets so the bar stays smooth.
 * - Preloads stage, characters (including `Change Character` events), icons, sounds,
 *   dialogue, and a song-specific hook — matching Doido's step distribution:
 *   0.2 stage/hud, 0.2→0.6 characters, 0.75 music, 0.85 dialogue, 0.95 custom, 1.0 done.
 * - Respects `StageData.forceNextDirectory` and `Paths.setCurrentLevel()` exactly like
 *   the original Phoenix `getNextState`.
 *
 * Set `loadAndSwitchState(target)` from anywhere. The loading screen only
 * presents on the way into the title screen at boot (executable open ->
 * TitleState) and when entering a song (`PlayState`, e.g. story mode /
 * freeplay -> song); every other target switches straight to the target
 * state without showing the screen.
 */
class LoadingState extends MusicBeatState
{
	// Persisted from caller so `getNextState` can set the library before `create()`
	private var targetState:NextState;
	private var stopMusicOnLoad:Bool;
	private var directory:String = 'shared';

	#if (cpp && !hl)
	private var mutex:Mutex;
	#end

	private var threadActive:Bool = true;

	private var behind:FlxGroup;
	private var bg:FlxSprite;
	private var loadBar:FlxSprite;
	private var loadPercent:Float = 0;

	// Doido-style tuning
	static inline var BG_COLOR:Int = 0xFFCAFF4D;
	static inline var BAR_COLOR:Int = 0xFFFF16D2;
	static inline var BAR_HEIGHT:Float = 12; // 20 - 8 in Doido

	var byeLol:Bool = false;
	var oldAnti:Bool = false;

	// Non-threaded queue: one task per frame keeps the bar animating on html5
	var preloadQueue:Array<Void->Void> = [];
	var preloadIndex:Int = 0;

	// For the scale bump
	var baseScale:Float = 0.75;
	var bumpScale:Float = 0.8;

	var bgColorSprite:FlxSprite = null;

	public function new(target:NextState, stopMusic:Bool = false, directory:String = 'shared')
	{
		super();
		targetState = target;
		stopMusicOnLoad = stopMusic;
		this.directory = directory;
	}

	override public function create():Void
	{
		super.create();

		// Mirror original: stop music early if requested
		if (stopMusicOnLoad && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		behind = new FlxGroup();
		add(behind);

		// Full-screen color (double size + screenCenter covers overscan/ultrawide like Doido)
		bgColorSprite = new FlxSprite().makeGraphic(FlxG.width * 2, FlxG.height * 2, BG_COLOR);
		bgColorSprite.screenCenter();
		add(bgColorSprite);

		// Center image — Doido uses `funkay.png`. Phoenix keeps that for authenticity
		// but also supports per-song overrides: `images/loading/<song>.png` or `images/funkay.png`.
		bg = new FlxSprite();
		var loadingKey:String = 'funkay';
		try
		{
			if (PlayState.SONG != null)
			{
				var songKey = 'loading/${Paths.formatToSongPath(PlayState.SONG.song)}';
				if (Paths.imageExists(songKey)) loadingKey = songKey;
			}
		}
		catch (e:Dynamic) {}
		var funkayGraphic = Paths.image(loadingKey);
		if (funkayGraphic == null)
			funkayGraphic = Paths.image('funkay');
		if (funkayGraphic == null)
			funkayGraphic = Paths.image('logoBumpin');
		if (funkayGraphic != null)
			bg.loadGraphic(funkayGraphic);
		else
			bg.makeGraphic(200, 200, 0xFFFFFFFF);

		bg.scale.set(bumpScale, bumpScale);
		bg.updateHitbox();
		bg.screenCenter();
		add(bg);

		loadBar = new FlxSprite().makeGraphic(FlxG.width - 16, Std.int(BAR_HEIGHT), BAR_COLOR);
		loadBar.y = FlxG.height - loadBar.height - 8;
		changeBarSize(0);
		add(loadBar);

		oldAnti = FlxSprite.defaultAntialiasing;
		FlxSprite.defaultAntialiasing = false;

		// Build the queue once; threaded path drains it on a background thread,
		// non-threaded drains one entry per `update()` so the bar animates.
		buildPreloadQueue();

		#if (cpp && !hl)
		// Threaded path (Doido's PRELOAD_SONG behavior) — runs entirely off the game thread
		mutex = new Mutex();
		var preloadThread = Thread.create(function()
		{
			mutex.acquire();
			drainQueueThreaded();
			FlxSprite.defaultAntialiasing = oldAnti;
			threadActive = false;
			mutex.release();
		});
		#else
		// Non-threaded: start slice execution in update(); flag true until done
		if (preloadQueue.length == 0)
		{
			loadPercent = 1.0;
			threadActive = false;
			FlxSprite.defaultAntialiasing = oldAnti;
		}
		else
		{
			threadActive = true;
			// keep oldAnti false until the queue finishes (restored below)
		}
		#end
	}

	/**
	 * Builds the queue of preload tasks. Mirrors Doido's LoadingState.create() steps:
	 *  - preloadPlayStuff (hitsounds, death, countdown)
	 *  - Rating + healthBar
	 *  - Stage
	 *  - Characters + death chars + icons
	 *  - Music (Inst/Voices)
	 *  - Dialogue
	 *  - Song-specific hook
	 */
	function buildPreloadQueue():Void
	{
		var SONG = PlayState.SONG;

		// No song queued: this is the boot -> title screen load. Preload the
		// title screen assets, then hand off to TitleState.
		if (SONG == null)
		{
			if (Std.isOfType(targetState, TitleState))
				preloadTitleStuff();
			else
			{
				// short fake queue so the bar still animates ~0.4s
				for (i in 0...6)
				{
					preloadQueue.push(function()
					{
						// no-op, just progress
					});
				}
			}
			return;
		}

		// Helper to push tasks
		inline function push(fn:Void->Void) preloadQueue.push(fn);

		// 1) PlayStuff — hitsounds, death, countdown
		push(function() preloadPlayStuff());

		// 2) Rating/hud stand-ins (Doido: Rating.preload + healthBar)
		push(function()
		{
			// Health bar image — caches the graphic
			try
			{
				var hb = Paths.image('healthBar');
				if (hb == null) hb = Paths.image('healthBar', 'shared');
				// Also preload timeBar variants Phoenix uses
				try Paths.image('timeBar') catch (e:Dynamic) {}
				try Paths.image('impostorTimeBar') catch (e:Dynamic) {}
				try Paths.image('dokiTimeBar') catch (e:Dynamic) {}
				try Paths.image('pixelUI/timeBar') catch (e:Dynamic) {}
			}
			catch (e:Dynamic) {}
		});

		// 3) Stage — cache stage file and attempt to cache its directory assets
		push(function()
		{
			try
			{
				var stageFile = StageData.getStageFile(SONG.stage != null ? SONG.stage : 'stage');
				// If the stage has a directory, touch a common asset to pull the library into cache.
				// We don't know the exact images without instantiating the stage, but marking the
				// file as read is enough to mirror Doido's `new Stage().reloadStageFromSong()` step.
				if (stageFile != null && stageFile.directory != null && stageFile.directory.length > 0)
				{
					// Trigger lookup caching for the stage's level folder
					Paths.setCurrentLevel(stageFile.directory);
				}
				else if (SONG.stage != null)
				{
					// Fallback: ensure stage json is cached
					Paths.getPath('stages/${SONG.stage}.json');
				}
			}
			catch (e:Dynamic) {}
		});

		// 4) Characters + icons — collect from SONG + Change Character / Change Stage events
		var charList:Array<String> = [];
		var playerChars:Array<String> = [SONG.player1];
		inline function addUnique(list:Array<String>, v:String)
		{
			if (v == null || v.length == 0) return;
			if (!list.contains(v)) list.push(v);
		}
		addUnique(charList, SONG.player1);
		addUnique(charList, SONG.player2);
		// Resolve gfVersion fallback exactly as PlayState.create does
		var gfVersion:String = SONG.gfVersion;
		if (gfVersion == null || gfVersion.length < 1)
		{
			var stageName = SONG.stage;
			if (stageName == null || stageName.length < 1)
				stageName = StageData.vanillaSongStage(Paths.formatToSongPath(SONG.song));
			gfVersion = switch (stageName)
			{
				case 'limo': 'gf-car';
				case 'mall' | 'mallEvil': 'gf-christmas';
				case 'school' | 'schoolEvil': 'gf-pixel';
				case 'tank': 'gf-tankmen';
				default: 'gf';
			}
			if (Paths.formatToSongPath(SONG.song) == 'stress') gfVersion = 'pico-speaker';
		}
		addUnique(charList, gfVersion);

		// Scan events for extra characters / stage changes like Doido does
		try
		{
			if (SONG.events != null)
			{
				for (eventData in SONG.events)
				{
					var time:Float = eventData[0];
					var sub:Array<Dynamic> = eventData[1];
					if (sub == null) continue;
					for (ev in sub)
					{
						if (ev == null || ev.length < 3) continue;
						var name:String = Std.string(ev[0]);
						var v1:String = Std.string(ev[1]);
						var v2:String = Std.string(ev[2]);
						if (name == 'Change Character')
						{
							addUnique(charList, v2);
							// Track player chars for death-variant preload (Doido checked bf/boyfriend)
							var lower = v1.toLowerCase();
							if (lower == 'bf' || lower == 'boyfriend' || lower == '0' || lower == 'player' || lower == 'boyfriend' || v1 == '1' && false)
							{
								// generic: if value1 hints at player, track
							}
							if (lower == 'bf' || lower == 'boyfriend') addUnique(playerChars, v2);
						}
						else if (name == 'Change Stage')
						{
							// Mimic Doido: reload stage directory and collect its gfVersion
							try
							{
								var sf = StageData.getStageFile(v1);
								if (sf != null && sf.directory != null && sf.directory.length > 0)
									Paths.setCurrentLevel(sf.directory);
							}
							catch (e:Dynamic) {}
						}
					}
				}
			}
		}
		catch (e:Dynamic) {}

		// Queue one task per character (so loadPercent steps mimic (0.6-0.2)/charCount)
		for (charName in charList)
		{
			var captured = charName;
			push(function()
			{
				#if (cpp && !hl)
				// Threaded: just instantiate to cache, no FlxGroup touch
				try
				{
					var isPlayer = playerChars.contains(captured);
					var c = new objects.Character(0, 0, captured, isPlayer);
					// Also cache death variant for player chars like Doido
					if (isPlayer)
					{
						try
						{
							var deathChar = captured + '-dead'; // same fallback as GameOverSubstate
							if (deathChar != null && deathChar.length > 0 && !charList.contains(deathChar))
							{
								var dead = new objects.Character(0, 0, deathChar, true);
								dead.destroy();
							}
						}
						catch (e:Dynamic) {}
					}
					// Icon (except gfVersion like Doido)
					if (captured != gfVersion)
					{
						try
						{
							var icon = new objects.HealthIcon(captured, false);
							icon.destroy();
						}
						catch (e:Dynamic) {}
					}
					c.destroy();
				}
				catch (e:Dynamic) {}
				#else
				// Main-thread: use behind add/remove to mirror Doido's caching trick
				try
				{
					var isPlayer = playerChars.contains(captured);
					var c = new objects.Character(0, 0, captured, isPlayer);
					addBehind(c);
					if (isPlayer)
					{
						try
						{
							var deathChar = captured + '-dead'; // same fallback as GameOverSubstate
							if (deathChar != null && deathChar.length > 0 && !charList.contains(deathChar))
							{
								var dead = new objects.Character(0, 0, deathChar, true);
								addBehind(dead);
							}
						}
						catch (e:Dynamic) {}
					}
					if (captured != gfVersion)
					{
						try
						{
							var icon = new objects.HealthIcon(captured, false);
							addBehind(icon);
						}
						catch (e:Dynamic) {}
					}
				}
				catch (e:Dynamic) {}
				#end
			});
		}

		// 5) Music — Inst / Voices (with erect/nightmare diff awareness via Paths helpers)
		push(function()
		{
			try
			{
				var diff:String = backend.CoolUtil.difficultyString();
				// songName sanitized as Paths expects
				var songName = Paths.formatToSongPath(SONG.song);
				// Inst
				try
				{
					var instSound = Paths.inst(songName, diff);
					// instSound may be a Sound or asset id (html5); touching it caches
					if (instSound != null) {}
				}
				catch (e:Dynamic) {}

				if (SONG.needsVoices)
				{
					// Player voices
					try
					{
						var pVoc = Paths.voices(songName, diff, 'Player');
						if (pVoc == null) pVoc = Paths.voices(songName, diff);
					}
					catch (e:Dynamic) {}
					// Opponent voices — mirrors Doido's extra -opp lookup
					try
					{
						var oVoc = Paths.voices(songName, diff, 'Opponent');
						if (oVoc != null) {}
					}
					catch (e:Dynamic) {}
					// Generic fallback
					try Paths.voices(songName, diff) catch (e:Dynamic) {}
				}
			}
			catch (e:Dynamic) {}
		});

		// 6) Dialogue — Psych-style json and Senpai txt
		push(function()
		{
			try
			{
				var songName = Paths.formatToSongPath(SONG.song);
				// Psych Engine dialogue json
				var diaJson:String = Paths.json(songName + '/dialogue');
				try
				{
					if (Paths.fileExists(diaJson, TEXT) || OpenFlAssets.exists(diaJson))
						Paths.getContent(diaJson);
				}
				catch (e:Dynamic) {}
				// Vanilla/Senpai txt
				var diaTxt:String = Paths.txt(songName + '/' + songName + 'Dialogue');
				try
				{
					if (Paths.fileExists(diaTxt, TEXT) || OpenFlAssets.exists(diaTxt))
						Paths.getContent(diaTxt);
				}
				catch (e:Dynamic) {}
				// Also warm DialogueBoxPsych sound cache
				try Paths.sound('dialogue') catch (e:Dynamic) {}
				try Paths.sound('dialogueClose') catch (e:Dynamic) {}
			}
			catch (e:Dynamic) {}
		});

		// 7) Song-specific hook — where modders put custom preloads (Doido switch(SONG.song))
		push(function()
		{
			// Add custom preloads here!  Mirrors Doido's comment in LoadingState.
			// Example: preload a mod-specific sprite or sound based on song name.
			switch (SONG.song.toLowerCase())
			{
				default:
					// trace('preloaded NOTHING extra lol');
			}
		});
	}

	#if (cpp && !hl)
	function drainQueueThreaded():Void
	{
		// Replicates Doido's stepped loadPercent values
		var total = preloadQueue.length;
		if (total == 0)
		{
			loadPercent = 1.0;
			return;
		}
		// Stage/hud already at 0.2 in Doido after first chunk; emulate proportionally
		loadPercent = 0.0;
		for (i in 0...total)
		{
			try preloadQueue[i]() catch (e:Dynamic) trace('LoadingState preload error at $i: $e');
			// Smooth stepped progress similar to Doido: first ~30% stage, rest chars/music/dialogue
			if (i == 0) loadPercent = 0.2;
			else if (i < total - 3) loadPercent = 0.2 + 0.4 * (i / (total - 1));
			else if (i == total - 3) loadPercent = 0.75;
			else if (i == total - 2) loadPercent = 0.85;
			else if (i == total - 1) loadPercent = 0.95;
		}
		loadPercent = 1.0;
		// trace('finished loading');
	}
	#end

	/**
	 * Preloads the title screen assets for the boot -> title screen load.
	 * TitleState.create() clears stored memory first, but everything here goes
	 * through `Paths.image` / `Paths.getSparrowAtlas`, which track assets in
	 * `currentTrackedAssets`, so they survive the clear and TitleState reuses
	 * them instead of hitching on the first frame.
	 */
	function preloadTitleStuff():Void
	{
		// Title art: logo, "press enter", Newgrounds logo.
		preloadQueue.push(function()
		{
			try Paths.getSparrowAtlas('logoBumpin') catch (e:Dynamic) {}
			try Paths.getSparrowAtlas('titleEnter') catch (e:Dynamic) {}
			try Paths.image('newgrounds_logo') catch (e:Dynamic) {}
		});

		// GF dancer is optional (content-stripped builds ship no art);
		// TitleState guards it the same way.
		preloadQueue.push(function()
		{
			try
			{
				if (Paths.image('gfDanceTitle') != null && Paths.fileExists('images/gfDanceTitle.xml', TEXT))
					Paths.getSparrowAtlas('gfDanceTitle');
			}
			catch (e:Dynamic) {}
		});

		// Intro text + title config.
		preloadQueue.push(function()
		{
			try Paths.getContent(Paths.txt('introText')) catch (e:Dynamic) {}
			try Paths.getTextFromFile('images/gfDanceTitle.json') catch (e:Dynamic) {}
		});
	}

	function preloadPlayStuff():Void
	{
		// Cache hitsounds, miss sounds, death, countdown — mirroring Doido's Paths.preloadPlayStuff()
		var preSounds:Array<String> = [];

		// Death / game-over. The retry track lives in shared/music, not in
		// sounds -- probing it as a sound only ever logged a bogus
		// "[ASSET SOUND] sounds/gameOverEnd.ogg | MISSING" line in the vlog
		// and preloaded nothing (see the 2026-11-11 crash bundle).
		preSounds.push('sounds/fnf_loss_sfx');
		preSounds.push('music/gameOverEnd');

		// Hitsounds (if enabled)
		try
		{
			var hsType:String = backend.ClientPrefs.hitsoundType;
			if (hsType != null && hsType.toLowerCase() != 'none')
				preSounds.push('sounds/hitsounds/${hsType.toLowerCase()}');
		}
		catch (e:Dynamic) {}

		for (i in 1...4) preSounds.push('sounds/missnote${i}');
		for (i in 0...4)
		{
			var sfx = ['intro3', 'intro2', 'intro1', 'introGo'][i];
			preSounds.push('sounds/${sfx}');
			// pixel variant
			preSounds.push('sounds/${sfx}-pixel');
		}
		// Countdown images (cache via Paths.image)
		var preGraphics:Array<String> = ['ready', 'set', 'go', 'healthBar'];
		for (k in preGraphics)
		{
			try Paths.image(k) catch (e:Dynamic) {}
		}
		for (snd in preSounds)
		{
			try
			{
				// Route by folder: 'sounds/x' caches through Paths.sound(),
				// 'music/x' through Paths.music(). Stripping both prefixes and
				// always calling Paths.sound() looked up music in sounds/.
				if (snd.startsWith('music/')) Paths.music(snd.substr(6));
				else Paths.sound(snd.startsWith('sounds/') ? snd.substr(7) : snd);
			}
			catch (e:Dynamic) {}
		}
	}

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		if (bgColorSprite != null)
		{
			bgColorSprite.setGraphicSize(width * 2, height * 2);
			bgColorSprite.updateHitbox();
			bgColorSprite.screenCenter();
		}
		if (bg != null) bg.screenCenter();
		if (loadBar != null)
		{
			loadBar.y = height - loadBar.height - 8;
			changeBarSize(loadBar.scale.x);
		}
	}

	// Doido's behind helper — add then immediately remove to cache graphic without staying on screen
	function addBehind(item:FlxBasic):Void
	{
		if (behind == null) return;
		behind.add(item);
		behind.remove(item);
		// Ensure the sprite disposes if we are on main-thread chunked mode
		// (characters/icons are cached via their graphics, the instance itself can be destroyed)
		try cast(item, FlxSprite).destroy() catch (e:Dynamic) {}
	}

	override function update(elapsed:Float):Void
	{
		super.update(elapsed);

		#if !(cpp && !hl)
		// Frame-sliced execute for non-threaded targets
		if (threadActive)
		{
			// Process one (or two) queue entries per frame to keep 60fps smooth
			var perFrame = 1;
			if (preloadQueue.length > 30) perFrame = 2; // bigger queues go faster
			for (f in 0...perFrame)
			{
				if (preloadIndex >= preloadQueue.length) break;
				try preloadQueue[preloadIndex]() catch (e:Dynamic) trace('LoadingState queue error $preloadIndex: $e');
				preloadIndex++;
				// Stepped progress like Doido
				if (preloadQueue.length > 0)
				{
					if (preloadIndex == 1) loadPercent = 0.2;
					else if (preloadIndex < preloadQueue.length - 2) loadPercent = 0.2 + 0.4 * (preloadIndex / preloadQueue.length);
					else loadPercent = 0.6 + 0.35 * (preloadIndex / preloadQueue.length);
				}
			}
			if (preloadIndex >= preloadQueue.length)
			{
				loadPercent = 0.95;
				// Give one more frame for bar to lerp before marking done (like Doido)
				if (loadBar.scale.x >= 0.90)
				{
					loadPercent = 1.0;
					threadActive = false;
					FlxSprite.defaultAntialiasing = oldAnti;
				}
			}
		}
		#end

		if (!threadActive && !byeLol && loadBar.scale.x >= 0.98)
		{
			byeLol = true;
			changeBarSize(1);
			// Doido set Main.skipClearMemory to keep preloaded assets for PlayState
			// In Phoenix, PlayState will call Paths.clearStoredMemory at the start,
			// so we do NOT want to clear; the assets we just cached are exactly
			// what PlayState needs. Marking a flag here would be ignored, so we
			// simply switch — Phoenix's PlayState.create() begins with
			// clearStoredMemory(false) which preserves tracked mod assets but still
			// frees transient bitmaps; our preloaded graphics are in currentTrackedAssets
			// and will survive. No skip flag needed.
			FlxG.switchState(cast targetState);
		}

		// Doido's playful bump on ACCEPT — scale BG up a notch
		var acceptPressed:Bool = false;
		try
		{
			acceptPressed = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE || controls.ACCEPT;
		}
		catch (e:Dynamic) acceptPressed = FlxG.keys.justPressed.ENTER || FlxG.keys.justPressed.SPACE;

		if (acceptPressed)
		{
			bg.scale.x += 0.04;
			bg.scale.y += 0.04;
		}

		var bgCalc = FlxMath.lerp(bg.scale.x, baseScale, elapsed * 6);
		bg.scale.set(bgCalc, bgCalc);
		bg.updateHitbox();
		bg.screenCenter();

		changeBarSize(FlxMath.lerp(loadBar.scale.x, loadPercent, elapsed * 6));
	}

	function changeBarSize(newSize:Float):Void
	{
		loadBar.scale.x = newSize;
		loadBar.updateHitbox();
		loadBar.screenCenter(X);
	}

	// --- Static helpers (preserve original API) ---

	public static function loadAndSwitchState(target:NextState, stopMusic = false):Void
	{
		FlxG.switchState(getNextState(target, stopMusic));
	}

	static function getNextState(target:NextState, stopMusic = false):NextState
	{
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if (weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);

		// The loading screen only shows on the way into the title screen at
		// boot (executable open -> TitleState) and when entering a song
		// (story mode / freeplay -> PlayState, plus other PlayState entries
		// like test play and next-song). Every other transition (menus,
		// options, editors, mods, ...) switches straight to the target state.
		// Function targets are resolved to instances up front so the target
		// can be checked; states are cheap to construct, `create()` still
		// runs on the switch like before.
		var resolved:FlxState = target.createInstance();

		if (isLoadingTarget(resolved))
		{
			#if NO_PRELOAD_ALL
			var loaded:Bool = false;
			if (PlayState.SONG != null)
			{
				try
				{
					loaded = isSoundLoaded(Paths.inst(PlayState.SONG.song))
						&& (!PlayState.SONG.needsVoices || isSoundLoaded(Paths.voices(PlayState.SONG.song)))
						&& isLibraryLoaded("shared")
						&& isLibraryLoaded(directory);
				}
				catch (e:Dynamic) loaded = false;
			}
			if (!loaded)
				return new LoadingState(resolved, stopMusic, directory);
			#else
			return new LoadingState(resolved, stopMusic, directory);
			#end
		}

		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		return resolved;
	}

	/**
	 * Whether `loadAndSwitchState` should present the loading screen for this
	 * target: only the title screen (boot) and songs (`PlayState`).
	 */
	static function isLoadingTarget(state:Dynamic):Bool
	{
		return Std.isOfType(state, PlayState) || Std.isOfType(state, TitleState);
	}

	#if NO_PRELOAD_ALL
	static function isSoundLoaded(path:Dynamic):Bool
	{
		// Compatibility shim for -DNO_PRELOAD_ALL builds (#55)
		// OpenFL's cache has hasSound(); lime.utils.AssetCache does not.
		try
		{
			var p:String = Std.string(path);
			return OpenFlAssets.cache.hasSound(p);
		}
		catch (e:Dynamic) return false;
	}

	static function isLibraryLoaded(library:String):Bool
	{
		try return OpenFlAssets.getLibrary(library) != null catch (e:Dynamic) return false;
	}
	#end
}
