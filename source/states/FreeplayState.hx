package states;

import backend.ClientPrefs;
import backend.FreeplayFilter;
import backend.FreeplayFilterStore;
import backend.ScreenLayout;
import backend.ViewportVisuals;
import backend.CoolUtil;
import backend.Conductor;
import backend.DiscordClient;
import backend.Highscore;
import backend.MenuMusic;
import backend.MusicBeatState;
import backend.Paths;
import backend.WeekData;
import data.Song;
import editors.ChartingState;
import flixel.addons.ui.FlxUIInputText;
import flixel.ui.FlxButton; // for formatting the note count
import flixel.util.FlxTimer;
import music.MusicPlayer;
import objects.Alphabet;
import objects.HealthIcon;
import objects.MovingCheckerboard;
import play.PlayState;
import states.substates.FreeplayFilterSubState;
import states.substates.FreeplayFilterSubState.FreeplayFilterHost;
import states.substates.GameplayChangersSubstate;
import states.substates.ResetScoreSubState;

import headers.States;

import backend.Controls;
import data.Section;
import objects.Character;
import objects.Note;

class FreeplayState extends MusicBeatState
{
	/**
	 * Order, mod filter, favourites-only switch and stars. Static so the page
	 * survives a trip into a song, and persisted by `FreeplayFilterStore`.
	 */
	public static var filter:FreeplayFilterState = new FreeplayFilterState();
	private static var filterLoaded:Bool = false;

	/** Every unlocked song, before the filter; `songs` is the filtered view. */
	public var allSongs:Array<SongMetadata> = [];

	/** `filter.revision` when the filter page opened; a change rebuilds the list. */
	private var filterRevision:Int = 0;

	var songs:Array<SongMetadata> = [];

	private static var curSelected:Int = 0;
	var curDifficulty:Int = -1;
	private static var lastDifficultyName:String = '';

	var scoreBG:FlxSprite;
	var scoreText:FlxText;
	var searchText:FlxText;
	var diffText:FlxText;
	var lerpScore:Float = 0;
	var lerpRating:Float = 0;
	var intendedScore:Float = 0;
	var intendedRating:Float = 0;
	var requiredRamLoad:Float = 0;
	var noteCount:Float = 0;

	var bottomString:String;
	var bottomText:FlxText;
	var bottomBG:FlxSprite;

	private var grpSongs:FlxTypedGroup<Alphabet>;
	private var grpIcons:FlxTypedGroup<HealthIcon>;

	public static var curPlaying:Bool = false;

	var lerpSelected:Float = 0;

	var bg:FlxSprite;
	var intendedColor:Int;
	var colorTween:FlxTween;
	var missingTextBG:FlxSprite;
	var missingText:FlxText;
	var songSearchText:FlxUIInputText;
	var buttonTop:FlxButton;
	var filterButton:FlxButton;
	/** "* FAVOURITE" next to the personal best, empty when the song is not starred. */
	var favouriteText:FlxText;
	/** Shown while the filter hides every song. */
	var emptyText:FlxText;
	/** Temporary one-liner ("No songs found matching your query"). */
	var noticeText:FlxText;
	var noticeTimer:FlxTimer;

	var player:MusicPlayer;
	private var layoutWidth:Int = 0;

	// Mic'd Up-style freeplay record.  The art is a two-frame Sparrow atlas;
	// the record itself rotates continuously while the selected character icon
	// stays centered on top of it.
	private var disc:FlxSprite;
	private var discIcon:HealthIcon;
	private var discTween:FlxTween;
	private var discAvailable:Bool = false;
	private static inline var DISC_ROTATION_SPEED:Float = 36;

	override public function onResize(width:Int, height:Int):Void
	{
		super.onResize(width, height);
		ViewportVisuals.cover(bg);
		ViewportVisuals.fill(missingTextBG);
		ViewportVisuals.fill(bottomBG, 26);
		if (missingText != null)
		{
			missingText.x = 50;
			missingText.fieldWidth = FlxG.width - 100;
		}
		if (bottomText != null) bottomText.fieldWidth = FlxG.width;
		if (songSearchText != null) songSearchText.x = FlxG.width - songSearchText.width;
		if (buttonTop != null) buttonTop.x = FlxG.width - buttonTop.width;
		if (searchText != null && buttonTop != null) searchText.x = buttonTop.x + 195;
		if (filterButton != null) filterButton.x = FlxG.width - filterButton.width;
		if (favouriteText != null) favouriteText.x = FlxG.width - favouriteText.width - 6;
		if (emptyText != null) emptyText.fieldWidth = FlxG.width;
		if (noticeText != null) noticeText.fieldWidth = FlxG.width;
		final shift:Float = ScreenLayout.contentLeft(FlxG.width) - ScreenLayout.contentLeft(layoutWidth);
		if (grpSongs != null)
			grpSongs.forEach(item -> { item.startPosition.x += shift; item.x += shift; });
		if (grpIcons != null) grpIcons.forEach(icon -> icon.x += shift);
		if (disc != null) positionDisc(true);
		layoutWidth = FlxG.width;
		if (scoreText != null && player != null) positionHighscore();
		if (player != null) player.onViewportResize();
	}

	override function create()
	{
		layoutWidth = FlxG.width;
		Paths.clearStoredMemory();

		persistentUpdate = true;
		PlayState.isStoryMode = false;
		WeekData.reloadWeekFiles(false);

		// Loaded once per session: the page edits the same object the list reads.
		if (!filterLoaded)
		{
			filterLoaded = true;
			filter = FreeplayFilterStore.load();
		}

		#if DISCORD_ALLOWED
		// Updating Discord Rich Presence
		DiscordClient.changePresence("In the Menus", null);
		#end

		final accept:String = "ACCEPT";
		final reject:String = "BACK";

		if(WeekData.weeksList.length < 1)
		{
			Paths.clearUnusedMemory();
			FlxTransitionableState.skipNextTransIn = true;
			persistentUpdate = false;
			var msg:String = "NO WEEKS ADDED FOR FREEPLAY\n\nPress " + accept + " to go to the Week Editor Menu.\nPress " + reject + " to return to Main Menu.";
			FlxG.switchState(new ErrorState(msg,
				function() FlxG.switchState(new editors.WeekEditorState()),
				function() FlxG.switchState(new MainMenuState())));
			return;
		}

		FreeplayStateHelpers.collectSongs(this);
		Mods.loadTopMod();

		// A saved mod filter may name a mod that is no longer installed; showing
		// an empty list with no way to notice would look like a broken menu.
		final knownMods:Array<String> = FreeplayStateHelpers.availableMods(this);
		if (filter.mod != null && !knownMods.contains(filter.mod)) filter.setMod(null);

		FreeplayStateHelpers.refreshSongs(this);
		filterRevision = filter.revision;

		#if PRELOAD_ALL
		if (!curPlaying) Conductor.changeBPM(TitleState.titleJSON.bpm);
		#end

		bg = new FlxSprite().loadGraphic(Paths.image('menuDesat'));
		bg.antialiasing = ClientPrefs.globalAntialiasing;
		ViewportVisuals.cover(bg);
		add(bg);
		add(new MovingCheckerboard(FlxColor.WHITE, 16.2, -37.8));

		grpSongs = new FlxTypedGroup<Alphabet>();
		add(grpSongs);
		grpIcons = new FlxTypedGroup<HealthIcon>();
		add(grpIcons);

		// Layering: the record is added right after the (still empty) song list
		// groups so that it draws over the song names and their icons.  The HUD
		// added further down (score box, help bar, search, music player) stays
		// above it.
		setupDisc();
		if (discAvailable)
		{
			final targetX:Float = ScreenLayout.contentLeft(FlxG.width) - 25;
			final targetY:Float = FlxG.height - 240;
			disc.x = targetX - 300;
			disc.y = targetY + 40;
			disc.scale.set(0, 0);
			discTween = FlxTween.tween(disc, {
				x: targetX,
				y: targetY,
				"scale.x": 1,
				"scale.y": 1
			}, 0.5, {ease: FlxEase.quartInOut});
		}

		for (i in 0...songs.length)
		{
			var songText:Alphabet = new Alphabet(ScreenLayout.contentLeft(FlxG.width) + 90, 320, songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - curSelected;
			grpSongs.add(songText);

			var maxWidth = 980;
			if (songText.width > maxWidth)
			{
				songText.scaleX = maxWidth / songText.width;
			}
			songText.snapToPosition();

			Mods.currentModDirectory = songs[i].folder;
			var icon:HealthIcon = new HealthIcon(songs[i].songCharacter);
			icon.sprTracker = songText;
			icon.ID = i;
			grpIcons.add(icon);
		}
		WeekData.setDirectoryFromWeek();

		scoreText = new FlxText(FlxG.width * 0.7, 5, 0, "", 32);
		scoreText.setFormat(Paths.font("vcr.ttf"), 32, FlxColor.WHITE, RIGHT);

		scoreBG = new FlxSprite(scoreText.x - 6, 0).makeGraphic(1, 66, 0xFF000000);
		scoreBG.alpha = 0.6;
		add(scoreBG);

		diffText = new FlxText(scoreText.x, scoreText.y + 36, 0, "", 24);
		diffText.font = scoreText.font;
		add(diffText);

		favouriteText = new FlxText(scoreText.x, diffText.y + 28, 0, '', 18);
		favouriteText.setFormat(Paths.font("vcr.ttf"), 18, FlxColor.WHITE, RIGHT);
		add(favouriteText);

		add(scoreText);

		missingTextBG = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		ViewportVisuals.fill(missingTextBG);
		missingTextBG.alpha = 0.6;
		missingTextBG.visible = false;
		add(missingTextBG);

		missingText = new FlxText(50, 0, FlxG.width - 100, '', 24);
		missingText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		missingText.scrollFactor.set();
		missingText.visible = false;
		add(missingText);

		if(curSelected >= songs.length) curSelected = 0;
		if (songs.length > 0)
		{
			bg.color = songs[curSelected].color;
			intendedColor = bg.color;
		}

		if(lastDifficultyName == '')
		{
			lastDifficultyName = CoolUtil.defaultDifficulty;
		}
		curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(lastDifficultyName)));

		if(curPlaying && instPlaying >= 0 && instPlaying < grpIcons.members.length)
		{
			grpIcons.members[instPlaying].canBounce = true;
		}

		MusicBeatState.windowNameSuffix = " - Freeplay Menu";

		bottomBG = new FlxSprite(0, FlxG.height - 26).makeGraphic(1, 1, 0xFF000000);
		ViewportVisuals.fill(bottomBG, 26);
		bottomBG.alpha = 0.6;
		add(bottomBG);

		#if PRELOAD_ALL
		var leText:String = "Press SPACE to listen / Press F to filter the list / Press CTRL for Gameplay Changers / Press RESET to Reset your Score.";
		var size:Int = 16;
		#else
		var leText:String = "Press F to filter the list / Press C for Gameplay Changers / Press Y to Reset your Score and Accuracy.";
		var size:Int = 18;
		#end
		if (mobile.MobileControls.enabled)
		{
			leText = "Press X to listen / Press F (or the FILTER button) to filter / Press C for Gameplay Changers / Press Y to Reset your Score.";
			size = 16;
		}
		bottomString = leText;
		bottomText = new FlxText(bottomBG.x, bottomBG.y + 4, FlxG.width, leText, size);
		bottomText.setFormat(Paths.font("vcr.ttf"), size, FlxColor.WHITE, CENTER);
		bottomText.scrollFactor.set();
		add(bottomText);

		songSearchText = new FlxUIInputText(0, scoreBG.y + scoreBG.height + 5, 500, '', 16);
		songSearchText.x = FlxG.width - songSearchText.width;
		add(songSearchText);

		buttonTop = new FlxButton(0, songSearchText.y + songSearchText.height + 5, "", function() {
			checkForSongsThatMatch(songSearchText.text);
		});
		buttonTop.setGraphicSize(Std.int(songSearchText.width), 50);
		buttonTop.updateHitbox();
		buttonTop.label.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK, RIGHT);
		buttonTop.x = FlxG.width - buttonTop.width;
		add(buttonTop);

		searchText = new FlxText(buttonTop.x + 195, 110, 100, "Search", 24);
		searchText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.BLACK);
		add(searchText);

		// Clickable twin of the F key, so the page is reachable without a keyboard.
		filterButton = new FlxButton(buttonTop.x, buttonTop.y + buttonTop.height + 6, "FILTER", function() openFilterPage());
		filterButton.setGraphicSize(Std.int(songSearchText.width), 40);
		filterButton.updateHitbox();
		filterButton.label.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.BLACK, CENTER);
		filterButton.x = FlxG.width - filterButton.width;
		add(filterButton);

		emptyText = new FlxText(0, 0, FlxG.width, 'No songs match this filter.\nPress F (or the FILTER button) to change it.', 24);
		emptyText.setFormat(Paths.font("vcr.ttf"), 24, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		emptyText.screenCenter();
		emptyText.scrollFactor.set();
		emptyText.visible = false;
		add(emptyText);

		noticeText = new FlxText(0, FlxG.height * 0.28, FlxG.width, '', 20);
		noticeText.setFormat(Paths.font("vcr.ttf"), 20, FlxColor.WHITE, CENTER, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		noticeText.scrollFactor.set();
		noticeText.visible = false;
		add(noticeText);

		player = new MusicPlayer(this);
		add(player);

		changeSelection();
		changeDiff();
		updateFavouriteText();
		updateEmptyState();

		FlxG.mouse.visible = !backend.TouchlessUI.isActive();

		addVirtualPad(LEFT_FULL, A_B_C_X_Y);

		Paths.clearUnusedMemory();
		super.create();
	}

	private function setupDisc():Void
	{
		disc = new FlxSprite();
		disc.scrollFactor.set();
		disc.antialiasing = ClientPrefs.globalAntialiasing;

		try
		{
			disc.frames = Paths.getSparrowAtlas('Freeplay_Discs');
		}
		catch (e:Dynamic)
		{
			// Content-stripped builds may not ship the optional menu artwork.
			// Keep Freeplay usable without the decorative record in that case.
			disc.frames = null;
		}

		discAvailable = disc.frames != null;
		add(disc);

		discIcon = new HealthIcon('bf');
		discIcon.scrollFactor.set();
		discIcon.visible = discAvailable;
		add(discIcon);

		if (discAvailable)
		{
			disc.animation.addByPrefix('dad', 'dad', 24, true);
			disc.animation.play('dad');
		}
	}

	private function positionDisc(resetScale:Bool = false):Void
	{
		if (disc == null) return;
		if (discTween != null)
		{
			discTween.cancel();
			discTween = null;
		}

		disc.x = ScreenLayout.contentLeft(FlxG.width) - 25;
		disc.y = FlxG.height - 240;
		if (resetScale && discAvailable) disc.scale.set(1, 1);
	}

	/** Select the closest bundled record label for a song's character. */
	public function updateFreeplayDisc(character:String):Void
	{
		if (discIcon == null) return;
		if (!discAvailable)
		{
			discIcon.visible = false;
			return;
		}

		var animationName:String = discAnimationForCharacter(character);
		if (disc.animation.getByName(animationName) == null)
			disc.animation.addByPrefix(animationName, animationName, 24, true);

		// Custom characters do not necessarily have a matching bundled disc.
		// Reuse the neutral dad record rather than leaving an empty sprite.
		if (disc.animation.getByName(animationName) == null)
			animationName = 'dad';
		if (disc.animation.getByName(animationName) != null)
			disc.animation.play(animationName);

		discIcon.changeIcon(character == null || character.length == 0 ? 'face' : character);
		discIcon.visible = true;
	}

	private function discAnimationForCharacter(character:String):String
	{
		if (character == null || character.length == 0) return 'dad';

		return switch (character.toLowerCase())
		{
			case 'gf' | 'gf-car' | 'gf-christmas' | 'gf-pixel': 'gf';
			case 'mom' | 'mom-car': 'mom';
			case 'monster' | 'monster-christmas': 'monster';
			case 'parents' | 'parents-christmas': 'parents-christmas';
			case 'pico': 'pico';
			case 'senpai' | 'senpai-angry' | 'senpai-pixel': 'senpai';
			case 'spirit' | 'spirit-pixel': 'spirit';
			case 'spooky': 'spooky';
			default: 'dad';
		};
	}

	private function updateDiscVisuals(elapsed:Float):Void
	{
		if (!discAvailable || disc == null) return;

		disc.angle += DISC_ROTATION_SPEED * elapsed;
		if (disc.angle >= 360) disc.angle -= 360;

		if (discIcon != null)
		{
			discIcon.x = disc.x + disc.width / 2 - discIcon.width / 2;
			discIcon.y = disc.y + disc.height / 2 - discIcon.height / 2;
			discIcon.angle = disc.angle;
			discIcon.scale.set(disc.scale.x, disc.scale.y);
		}
	}

	function checkForSongsThatMatch(?start:String = '')
	{
		FreeplayStateHelpers.checkForSongsThatMatch(this, start);
	}

	function regenerateSongs(?start:String = '') {
		FreeplayStateHelpers.regenerateSongs(this, start);
	}

	override function closeSubState() {
		// The filter page edits `filter` in place; rebuild (and remember) only
		// when something actually changed, so closing other substates is free.
		if (filter.revision != filterRevision)
		{
			filterRevision = filter.revision;
			applyFreeplayFilter();
			FreeplayFilterStore.save(filter);
			// "Reset filters" clears the query in the page; keep the search box
			// showing what the list is actually filtered by.
			if (songSearchText != null && songSearchText.text != filter.query) songSearchText.text = filter.query;
		}
		changeSelection(0, false);
		persistentUpdate = true;
		if (virtualPad != null) virtualPad.visible = mobile.MobileControls.enabled;
		super.closeSubState();
	}

	/** Rebuilds the list with the current filter, then keeps the highlight. */
	public function applyFreeplayFilter():Void
	{
		FreeplayStateHelpers.refreshSongs(this);
		FreeplayStateHelpers.regenList(this);
		updateFavouriteText();
		updateEmptyState();
	}

	/** Opens the filter page: F, the FILTER button, or the right shoulder button. */
	function openFilterPage():Void
	{
		persistentUpdate = false;
		if (virtualPad != null) virtualPad.visible = false;
		filterRevision = filter.revision;

		final host:FreeplayFilterHost = {
			isStarred: function() return isSelectedStarred(),
			toggleStar: function() return toggleSelectedStar(),
			randomSong: function() selectRandomSong(),
			currentSong: function() {
				final song:SongMetadata = FreeplayStateHelpers.selectedSong(this);
				return song == null ? '' : song.songName + ' (' + FreeplayFilter.modLabel(song.folder) + ')';
			}
		};

		openSubState(new FreeplayFilterSubState(filter, FreeplayStateHelpers.availableMods(this), host));
		FlxG.sound.play(Paths.sound('scrollMenu'), 0.6);
	}

	/** True when the highlighted song is starred. */
	public function isSelectedStarred():Bool
	{
		final song:SongMetadata = FreeplayStateHelpers.selectedSong(this);
		return song != null && filter.isStarred(song.songName, song.folder);
	}

	/** Flips the star of the highlighted song; returns the new value. */
	public function toggleSelectedStar():Bool
	{
		final song:SongMetadata = FreeplayStateHelpers.selectedSong(this);
		if (song == null) return false;
		final value:Bool = filter.toggleStar(song.songName, song.folder);
		updateFavouriteText();
		return value;
	}

	/** Highlights a random song out of whatever the filter currently keeps. */
	public function selectRandomSong():Void
	{
		applyFreeplayFilter();
		if (songs.length == 0) return;

		final candidates:Array<Int> = [];
		for (i in 0...songs.length)
		{
			// A "random" pick that lands on the song already highlighted is
			// just noise; only a one-song list may repeat it.
			if (i != curSelected || songs.length == 1) candidates.push(i);
		}

		final pick:Int = FreeplayFilter.randomPick(candidates, Math.random());
		if (pick < 0) return;
		curSelected = pick;
		changeSelection(0);
		changeDiff();
	}

	/** Shows the star of the highlighted song next to the personal best. */
	public function updateFavouriteText():Void
	{
		if (favouriteText == null) return;
		favouriteText.text = isSelectedStarred() ? '* FAVOURITE' : '';
		favouriteText.x = FlxG.width - favouriteText.width - 6;
		// `MusicPlayer` hides the personal-best block while a preview plays.
		favouriteText.visible = (player == null || !player.playingMusic) && favouriteText.text.length > 0;
	}

	/** The persistent "nothing matches" line, shown only with an empty list. */
	function updateEmptyState():Void
	{
		if (emptyText == null) return;
		emptyText.visible = songs.length == 0;
		if (emptyText.visible) emptyText.screenCenter();
	}

	/** One-line message above the list, hidden again after a few seconds. */
	public function showNotice(message:String):Void
	{
		if (noticeText == null) return;
		noticeText.text = message;
		noticeText.visible = message.length > 0;
		noticeText.screenCenter(X);
		noticeText.y = FlxG.height * 0.28;

		if (noticeTimer != null) noticeTimer.cancel();
		if (message.length == 0) return;
		noticeTimer = new FlxTimer().start(4, function(_) {
			if (noticeText != null) noticeText.visible = false;
		});
	}

	public function addSong(songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		FreeplayStateHelpers.addSong(this, songName, weekNum, songCharacter, color);
	}

	function weekIsLocked(name:String):Bool {
		return FreeplayStateHelpers.weekIsLocked(this, name);
	}

	function regenList() {
		FreeplayStateHelpers.regenList(this);
	}

	public static var instPlaying:Int = -1;
	public static var vocals:FlxSound = null;
	public static var opponentVocals:FlxSound = null;
	var holdTime:Float = 0;
	override function update(elapsed:Float)
	{
		updateDiscVisuals(elapsed);

		if (FlxG.sound.music != null)
		{
			Conductor.songPosition = FlxG.sound.music.time;
			// Only the menu theme is ramped (0.7 was the old fixed ceiling); a
			// Freeplay preview playing on the same channel keeps its own volume.
			MenuMusic.ramp(elapsed, 0.7);
		}

		/*
		for (i in 0...iconArray.length)
		{
				iconArray[i].scale.set(FlxMath.lerp(iconArray[i].scale.x, 1, elapsed * 9),
				FlxMath.lerp(iconArray[i].scale.y, 1, elapsed * 9));
		}
		*/

		lerpScore = Math.floor(FlxMath.lerp(lerpScore, intendedScore, CoolUtil.boundTo(elapsed * 24, 0, 1)));
		lerpRating = FlxMath.lerp(lerpRating, intendedRating, CoolUtil.boundTo(elapsed * 12, 0, 1));

		if (Math.abs(lerpScore - intendedScore) <= 10)
			lerpScore = intendedScore;
		if (Math.abs(lerpRating - intendedRating) <= 0.01)
			lerpRating = intendedRating;

		var ratingSplit:Array<String> = Std.string(Highscore.floorDecimal(lerpRating * 100, 2)).split('.');
		if(ratingSplit.length < 2) { //No decimals, add an empty space
			ratingSplit.push('');
		}

		while(ratingSplit[1].length < 2) { //Less than 2 decimals in it, add decimals then
			ratingSplit[1] += '0';
		}

		try {
			var newScoreText:String = 'PERSONAL BEST: ' + lerpScore + ' (' + ratingSplit?.join('.') + '%)';
			if (scoreText.text != newScoreText) scoreText.text = newScoreText;
		}
		catch(e){}
		positionHighscore();
		updateEmptyState();

		var upP = controls.UI_UP_P;
		var downP = controls.UI_DOWN_P;
		var accepted = controls.ACCEPT;
		var space:Bool = FlxG.keys.justPressed.SPACE || virtualPad.buttonX.justPressed || FlxG.gamepads.anyJustPressed(X);
		var filterKey:Bool = FlxG.keys.justPressed.F || FlxG.gamepads.anyJustPressed(RIGHT_SHOULDER);
		var ctrl:Bool = FlxG.keys.justPressed.CONTROL || virtualPad.buttonC.justPressed
			|| FlxG.keys.justPressed.MENU || backend.TouchlessUI.isMenuPressed() || FlxG.gamepads.anyJustPressed(LEFT_SHOULDER);

		var shiftMult:Int = 1;
		if (FlxG.keys.pressed.SHIFT) shiftMult = 3;

		try {
			if (songSearchText?.hasFocus)
			{
				if (controls.BACK)
					songSearchText.hasFocus = false;
			}
			else
			{
				if (!player.playingMusic)
				{
					if(songs.length > 1)
					{
						if (upP)
						{
							changeSelection(-shiftMult);
							holdTime = 0;
						}
						if (downP)
						{
							changeSelection(shiftMult);
							holdTime = 0;
						}

						if(controls.UI_DOWN || controls.UI_UP)
						{
							var checkLastHold:Int = Math.floor((holdTime - 0.5) * 10);
							holdTime += elapsed;
							var checkNewHold:Int = Math.floor((holdTime - 0.5) * 10);
							if(holdTime > 0.5 && checkNewHold - checkLastHold > 0)
							{
								changeSelection((checkNewHold - checkLastHold) * (controls.UI_UP ? -shiftMult : shiftMult));
								changeDiff();
							}
						}

						if(FlxG.mouse.wheel != 0)
						{
							FlxG.sound.play(Paths.sound('scrollMenu'), 0.2);
							changeSelection(-shiftMult * FlxG.mouse.wheel, false);
							changeDiff();
						}
					}


					if (controls.UI_LEFT_P)
						changeDiff(-1);
					else if (controls.UI_RIGHT_P)
						changeDiff(1);
					else if (upP || downP) changeDiff();
				}


				if (controls.BACK)
				{
					curPlaying = false;
					if (player.playingMusic)
					{
						FlxG.sound.music.stop();
						destroyFreeplayVocals();
						FlxG.sound.music.volume = 0;
						instPlaying = -1;

						player.playingMusic = false;
						player.switchPlayMusic();

						Paths.playMenuMusic(true);
						FlxTween.tween(FlxG.sound.music, {volume: MenuMusic.targetVolume()}, 1);
					}
					else
					{
						persistentUpdate = false;
						if(colorTween != null) {
							colorTween.cancel();
						}
						FlxG.sound.play(Paths.sound('cancelMenu'));
						FlxG.switchState(MainMenuState.new);
						FlxG.mouse.visible = false;
					}
				}

				if (filterKey && !player.playingMusic)
				{
					openFilterPage();
				}
				else if(ctrl && !player.playingMusic)
				{
					persistentUpdate = false;
					if (virtualPad != null) virtualPad.visible = false;
					openSubState(new GameplayChangersSubstate());
				}
				else if(space && songs.length > 0)
				{
					requiredRamLoad = 0;
					noteCount = 0;

					var poop:String = Highscore.formatSong(songs[curSelected].songName.toLowerCase(), curDifficulty);
					var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
					#if MODS_ALLOWED
					if(instPlaying != curSelected && !player.playingMusic)
					{
						// Paths.inst() returns a loaded Sound, not a path, so it must never be
						// handed to an exists() check -- use Paths.instExists() instead.
						if(Paths.instExists(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase()) || sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop)) || sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)))
							FreeplayStateHelpers.playSong(this);
						else
							FreeplayStateHelpers.songJsonPopup(this);
					}
					#else
					if(instPlaying != curSelected && !player.playingMusic)
					{
						if(Paths.instExists(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase()) || OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop)))
							FreeplayStateHelpers.playSong(this);
						else
							FreeplayStateHelpers.songJsonPopup(this);
					}
					#end
					else if (instPlaying == curSelected && player.playingMusic)
					{
						player.pauseOrResume(!player.playing);
					}
				}

				else if (accepted && !player.playingMusic && songs.length > 0)
				{
					persistentUpdate = false;
					var songLowercase:String = Paths.formatToSongPath(songs[curSelected].songName);
					var poop:String = Highscore.formatSong(songLowercase, curDifficulty);

					trace(poop);

					CoolUtil.currentDifficulty = CoolUtil.difficultyString();

					#if sys
					if(sys.FileSystem.exists(Paths.json(songLowercase + '/' + poop)) || OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))
						#if MODS_ALLOWED || sys.FileSystem.exists(Paths.modsJson(songLowercase + '/' + poop)) || OpenFlAssets.exists(Paths.modsJson(songLowercase + '/' + poop)) #end) {
					#else
					if(OpenFlAssets.exists(Paths.json(songLowercase + '/' + poop))) {
					#end
					PlayState.SONG = Song.loadFromJson(poop, songLowercase);
					PlayState.storyDifficulty = curDifficulty;

					PlayState.isStoryMode = PlayState.wasOriginallyFreeplay = ClientPrefs.alwaysTriggerCutscene;

					trace('CURRENT WEEK: ' + WeekData.getWeekFileName());
					if(colorTween != null) {
						colorTween.cancel();
					}

					curPlaying = false;

					if (FlxG.keys.pressed.SHIFT) {
						LoadingState.loadAndSwitchState(ChartingState.new);
					}else{
						LoadingState.loadAndSwitchState(PlayState.new);
					}

					FlxG.sound.music.volume = 0;
					FlxG.mouse.visible = false;

					destroyFreeplayVocals();

						#if sys
						// Anti-crash sanity check for the week author. Two things used to
						// make it fire on perfectly fine songs:
						//   * Paths.inst() returns a loaded Sound (not a path), so
						//     FileSystem.exists() on it was always false;
						//   * the chart lives at data/<song>/<chart>.json, not at
						//     data/<chart>/<chart>.json, and mod charts live under mods/.
						// The result was a bogus -- and on Windows modal, game-blocking --
						// "this song has no JSON or audio" dialog on every song pick.
						final chartName:String = songLowercase + '/' + poop;
						final chartExists:Bool = sys.FileSystem.exists(Paths.json(chartName)) || OpenFlAssets.exists(Paths.json(chartName))
							#if MODS_ALLOWED || sys.FileSystem.exists(Paths.modsJson(chartName)) || OpenFlAssets.exists(Paths.modsJson(chartName)) #end;
						final audioExists:Bool = Paths.instExists(songLowercase, CoolUtil.difficulties[curDifficulty].toLowerCase());

						if(audioExists && !chartExists) { //the json doesn't exist, but the song files do, or you put a typo in the name
							CoolUtil.coolError("The JSON's name does not match with  " + poop + "!\nTry making them match.", "JS Engine Anti-Crash Tool");
						} else if(chartExists && !audioExists) {//the json exists, but the song files don't
							CoolUtil.coolError("Your song seems to not have an Inst.ogg (or Inst.mp3), check the folder name in 'songs'!", "JS Engine Anti-Crash Tool");
						} else if(!chartExists && !audioExists) { //neither the json nor the song files actually exist
							CoolUtil.coolError("It appears that " + poop + " doesn't actually have a JSON, nor does it actually have voices/instrumental files!\nMaybe try fixing its name in weeks/" + WeekData.getWeekFileName() + "?", "JS Engine Anti-Crash Tool");
						}
						#end
					}
				}
				else if ((controls.RESET || virtualPad.buttonY.justPressed || FlxG.gamepads.anyJustPressed(Y)) && !player.playingMusic && songs.length > 0) {
					persistentUpdate = false;
					if (virtualPad != null) virtualPad.visible = false;
					openSubState(new ResetScoreSubState(songs[curSelected].songName, curDifficulty, songs[curSelected].songCharacter));
					FlxG.sound.play(Paths.sound('scrollMenu'));
				}
			}
		}
		catch(e){}
		super.update(elapsed);

		if (grpSongs != null && (songSearchText == null || !songSearchText.hasFocus))
		{
			final pointed:Int = syncPointingCursor(grpSongs.members, curSelected);
			if (pointed != curSelected)
				changeSelection(pointed - curSelected);
		}
		else if (pointingCursor != null)
			pointingCursor.visible = false;
	}

	function getVocalFromCharacter(char:String)
	{
		return FreeplayStateHelpers.getVocalFromCharacter(this, char);
	}

	public static function destroyFreeplayVocals() {
		FreeplayStateHelpers.destroyFreeplayVocals();
	}

	function changeDiff(change:Int = 0)
	{
		FreeplayStateHelpers.changeDiff(this, change);
	}

	function changeSelection(change:Int = 0, playSound:Bool = true)
	{
		FreeplayStateHelpers.changeSelection(this, change, playSound);
	}

	private function positionHighscore() {
		FreeplayStateHelpers.positionHighscore(this);
	}
	override function beatHit() {
		super.beatHit();

		if (curPlaying && instPlaying >= 0 && instPlaying < grpIcons.members.length)
			if (grpIcons.members[instPlaying] != null && grpIcons.members[instPlaying].canBounce) grpIcons.members[instPlaying].bounce();
	}
	var _drawDistance:Int = 4;
	var _lastVisibles:Array<Int> = [];
	public function updateTexts(elapsed:Float = 0.0)
	{
		FreeplayStateHelpers.updateTexts(this, elapsed);
	}
}

class SongMetadata
{
	public var songName:String = "";
	public var week:Int = 0;
	public var songCharacter:String = "";
	public var color:Int = -7179779;
	public var folder:String = "";

	public function new(song:String, week:Int, songCharacter:String, color:Int)
	{
		this.songName = song;
		this.week = week;
		this.songCharacter = songCharacter;
		this.color = color;
		this.folder = Mods.currentModDirectory;
		if(this.folder == null) this.folder = '';
	}
}
