package states.helpers;

import backend.ClientPrefs;
import backend.FreeplayFilter;
import backend.FreeplayFilterStore;
import backend.ScreenLayout;
import backend.CoolUtil;
import backend.Conductor;
import backend.Highscore;
#if MODS_ALLOWED
#end
import backend.Paths;
import backend.WeekData;
import data.Song;
import flixel.FlxG;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxColor;
import flixel.util.FlxDestroyUtil;
import flixel.util.FlxStringUtil;
import haxe.Json;
import lime.utils.Assets;
import objects.Alphabet;
import objects.HealthIcon;
import openfl.utils.AssetType;
import states.FreeplayState;
import states.FreeplayState.SongMetadata;
import states.StoryMenuState;
#if sys
import sys.io.File;
#end

import data.Section;
import objects.Character;
import objects.Note;
import play.PlayState;

@:access(states.FreeplayState)
class FreeplayStateHelpers
{
	// Song list generation/search

	/**
	 * Rebuilds the whole list from the unlocked weeks and applies the filter.
	 * `start` replaces the search text, so the search box and the filter page
	 * share one code path.
	 */
	public static function regenerateSongs(state:FreeplayState, ?start:String = '') {
		for (funnyIcon in state.grpIcons.members)
			funnyIcon.canBounce = false;
		FreeplayState.curPlaying = false;

		if (start != null) FreeplayState.filter.setQuery(start);
		collectSongs(state);
		refreshSongs(state);
		regenList(state);
	}

	/** Fills `state.allSongs` with every unlocked week's songs, unfiltered. */
	public static function collectSongs(state:FreeplayState):Void
	{
		state.allSongs = [];
		for (i in 0...WeekData.weeksList.length) {
			if(weekIsLocked(state, WeekData.weeksList[i])) continue;

			var leWeek:WeekData = WeekData.weeksLoaded.get(WeekData.weeksList[i]);
			WeekData.setDirectoryFromWeek(leWeek);
			for (song in leWeek.songs)
			{
				var colors:Array<Int> = song[2];
				if(colors == null || colors.length < 3)
				{
					colors = [146, 113, 253];
				}
				addSong(state, song[0], i, song[1], FlxColor.fromRGB(colors[0], colors[1], colors[2]));
			}
		}
	}

	/** One filter entry per collected song, with the best accuracy the save knows. */
	public static function filterEntries(state:FreeplayState):Array<FreeplayFilterEntry>
	{
		final paths:Array<String> = [];
		for (song in state.allSongs) paths.push(Paths.formatToSongPath(song.songName));

		final stats:Map<String, FreeplaySongStat> = FreeplayFilter.collectStats(paths, Highscore.songScores, Highscore.songRating);
		final entries:Array<FreeplayFilterEntry> = [];
		for (song in state.allSongs)
		{
			final stat:FreeplaySongStat = stats.get(Paths.formatToSongPath(song.songName));
			entries.push(new FreeplayFilterEntry(song.songName, song.folder,
				stat == null ? -1 : stat.bestAccuracy, stat == null ? false : stat.played));
		}
		return entries;
	}

	/**
	 * Rewrites `state.songs` from `state.allSongs` using the current filter and
	 * sort, then moves the highlight to the same song when it survived the
	 * filter (the first entry otherwise).
	 */
	public static function refreshSongs(state:FreeplayState):Void
	{
		final previous:SongMetadata = selectedSong(state);

		final entries:Array<FreeplayFilterEntry> = filterEntries(state);
		final order:Array<Int> = FreeplayFilter.order(entries, FreeplayState.filter);

		final filtered:Array<SongMetadata> = [];
		for (index in order) filtered.push(state.allSongs[index]);
		state.songs = filtered;

		var next:Int = 0;
		if (previous != null)
		{
			for (i in 0...filtered.length)
			{
				if (sameSong(filtered[i], previous))
				{
					next = i;
					break;
				}
			}
		}
		FreeplayState.curSelected = next;
	}

	/** The highlighted song, or `null` when the filter emptied the list. */
	public static function selectedSong(state:FreeplayState):SongMetadata
	{
		if (state.songs.length == 0) return null;
		if (FreeplayState.curSelected < 0 || FreeplayState.curSelected >= state.songs.length) return null;
		return state.songs[FreeplayState.curSelected];
	}

	/** Mod folders of the collected songs, base game (`''`) first. */
	public static function availableMods(state:FreeplayState):Array<String>
	{
		return FreeplayFilter.availableMods(filterEntries(state));
	}

	static function sameSong(one:SongMetadata, two:SongMetadata):Bool
	{
		return one != null && two != null && one.songName == two.songName && one.folder == two.folder;
	}

	public static function checkForSongsThatMatch(state:FreeplayState, ?start:String = '')
	{
		if (state.player.playingMusic) return;

		final previous:String = FreeplayState.filter.query;
		final query:String = start == null ? '' : start;
		FreeplayState.filter.setQuery(query);

		if (state.allSongs.length == 0) collectSongs(state);

		// Nothing matched: keep the list the player was browsing and say so.
		if (query.length > 0 && FreeplayFilter.count(filterEntries(state), FreeplayState.filter) == 0)
		{
			FreeplayState.filter.setQuery(previous);
			state.showNotice('No songs found matching your query');
			return;
		}

		refreshSongs(state);
		regenList(state);
		FreeplayFilterStore.save(FreeplayState.filter);
		// The search box already rebuilt the list; closing a substate later must
		// not rebuild it a second time.
		state.filterRevision = FreeplayState.filter.revision;
	}

	public static function addSong(state:FreeplayState, songName:String, weekNum:Int, songCharacter:String, color:Int)
	{
		state.allSongs.push(new SongMetadata(songName, weekNum, songCharacter, color));
	}

	public static function weekIsLocked(state:FreeplayState, name:String):Bool {
		var leWeek:WeekData = WeekData.weeksLoaded.get(name);
		return (!leWeek.startUnlocked && leWeek.weekBefore.length > 0 && (!StoryMenuState.weekCompleted.exists(leWeek.weekBefore) || !StoryMenuState.weekCompleted.get(leWeek.weekBefore)));
	}

	public static function regenList(state:FreeplayState) {
			state.grpSongs.forEach(song -> {
				state.grpSongs.remove(song, true);
				song.destroy();
			});
			state.grpIcons.forEach(icon -> {
				state.grpIcons.remove(icon, true);
				icon.destroy();
			});

			//we clear the remaining ones
			state.grpSongs.clear();
			state.grpIcons.clear();

		// The filter can hide everything (favourites-only with no stars, a mod
		// that was removed). Keep the HUD honest instead of indexing nothing.
		if (state.songs.length == 0)
		{
			state.intendedScore = 0;
			state.intendedRating = 0;
			if (state.scoreText != null) state.scoreText.text = '';
			if (state.diffText != null) state.diffText.text = '';
			return;
		}

		for (i in 0...state.songs.length)
		{
			var songText:Alphabet = new Alphabet(ScreenLayout.contentLeft(FlxG.width) + 90, 320, state.songs[i].songName, true);
			songText.isMenuItem = true;
			songText.targetY = i - FreeplayState.curSelected;
			state.grpSongs.add(songText);

			var maxWidth = 980;
			if (songText.width > maxWidth)
			{
				songText.scaleX = maxWidth / songText.width;
			}
			songText.snapToPosition();

			Mods.currentModDirectory = state.songs[i].folder;

			var icon:HealthIcon = new HealthIcon(state.songs[i].songCharacter);
			icon.sprTracker = songText;
			icon.ID = i;
			state.grpIcons.add(icon);
		}

		changeSelection(state);
		changeDiff(state);
	}

	// Selection/difficulty

	public static function changeSelection(state:FreeplayState, change:Int = 0, playSound:Bool = true)
	{
		if (state.player.playingMusic) return;
		// Nothing to select: the filter hid every song (see `regenList`).
		if (state.songs.length == 0) return;

		if(playSound) FlxG.sound.play(Paths.sound('scrollMenu'), 0.4);

		FreeplayState.curSelected += change;

		if (FreeplayState.curSelected < 0)
			FreeplayState.curSelected = state.songs.length - 1;
		if (FreeplayState.curSelected >= state.songs.length)
			FreeplayState.curSelected = 0;

		var newColor:Int = state.songs[FreeplayState.curSelected].color;
		if(newColor != state.intendedColor) {
			if(state.colorTween != null) {
				state.colorTween.cancel();
			}
			state.intendedColor = newColor;
			state.colorTween = FlxTween.color(state.bg, 1, state.bg.color, state.intendedColor, {
				onComplete: function(twn:FlxTween) {
					state.colorTween = null;
				}
			});
		}

		state.intendedScore = Highscore.getScore(state.songs[FreeplayState.curSelected].songName, state.curDifficulty);
		state.intendedRating = Highscore.getRating(state.songs[FreeplayState.curSelected].songName, state.curDifficulty);

		var selectionIndex:Int = 0;

		for (i in state.grpIcons.members) i.alpha = (i.ID == FreeplayState.curSelected ? 1 : 0.6);

		for (item in state.grpSongs.members)
		{
			item.targetY = item.ID - FreeplayState.curSelected;
			item.alpha = 0.6;
			if (item.targetY == 0) item.alpha = 1;
		}

		for (item in state.grpSongs.members)
		{
			item.targetY = selectionIndex - FreeplayState.curSelected;
			selectionIndex++;

			item.alpha = 0.6;

			if (item.targetY == 0)
			{
				item.alpha = 1;
			}
		}

		Mods.currentModDirectory = state.songs[FreeplayState.curSelected].folder;
		PlayState.storyWeek = state.songs[FreeplayState.curSelected].week;
		state.updateFreeplayDisc(state.songs[FreeplayState.curSelected].songCharacter);
		state.updateFavouriteText();

		CoolUtil.difficulties = CoolUtil.defaultDifficulties.copy();
		var diffStr:String = WeekData.getCurrentWeek().difficulties;
		if(diffStr != null) diffStr = diffStr.trim(); //Bother you HTML5

		if(diffStr != null && diffStr.length > 0)
		{
			var diffs:Array<String> = diffStr.split(',');
			var i:Int = diffs.length - 1;
			while (i > 0)
			{
				if(diffs[i] != null)
				{
					diffs[i] = diffs[i].trim();
					if(diffs[i].length < 1) diffs.remove(diffs[i]);
				}
				--i;
			}

			if(diffs.length > 0 && diffs[0].length > 0)
			{
				CoolUtil.difficulties = diffs;
			}
		}

		if(CoolUtil.difficulties.contains(CoolUtil.defaultDifficulty))
		{
			state.curDifficulty = Math.round(Math.max(0, CoolUtil.defaultDifficulties.indexOf(CoolUtil.defaultDifficulty)));
		}
		else
		{
			state.curDifficulty = 0;
		}

		if (Song.hasDifficulty(state.songs[FreeplayState.curSelected].songName.toLowerCase(), 'jshard') && ClientPrefs.JSEngineRecharts)
			CoolUtil.difficulties.push('jshard');

		if (CoolUtil.defaultSongs.contains(state.songs[FreeplayState.curSelected].songName.toLowerCase()) && Song.hasDifficulty(state.songs[FreeplayState.curSelected].songName.toLowerCase(), 'erect'))
		{
			CoolUtil.difficulties.push('erect');
			CoolUtil.difficulties.push('nightmare');
		}

		if (state.songs[FreeplayState.curSelected].songName.toLowerCase() == 'darnell')
		{
			CoolUtil.difficulties.push('bf');
			if (ClientPrefs.JSEngineRecharts)
				CoolUtil.difficulties.push('jsbf');
		}

		// Offer Mic'd Up difficulties only for songs that actually have charts.
		for (difficulty in ['Noob', 'Expert', 'Insane'])
			if (!CoolUtil.difficulties.contains(difficulty) && Song.hasDifficulty(state.songs[FreeplayState.curSelected].songName, difficulty))
				CoolUtil.difficulties.push(difficulty);

		var newPos:Int = CoolUtil.difficulties.indexOf(FreeplayState.lastDifficultyName);
		//trace('Pos of ' + lastDifficultyName + ' is ' + newPos);
		if(newPos > -1)
		{
			state.curDifficulty = newPos;
		}
	}

	public static function changeDiff(state:FreeplayState, change:Int = 0)
	{
		if (state.player.playingMusic) return;
		if (state.songs.length == 0)
		{
			if (state.diffText != null) state.diffText.text = '';
			return;
		}

		state.curDifficulty += change;

		if (state.curDifficulty < 0)
			state.curDifficulty = CoolUtil.difficulties.length-1;
		if (state.curDifficulty >= CoolUtil.difficulties.length)
			state.curDifficulty = 0;

		FreeplayState.lastDifficultyName = CoolUtil.difficulties[state.curDifficulty];

		#if !switch
		state.intendedScore = Highscore.getScore(state.songs[FreeplayState.curSelected].songName, state.curDifficulty);
		state.intendedRating = Highscore.getRating(state.songs[FreeplayState.curSelected].songName, state.curDifficulty);
		#end

		PlayState.storyDifficulty = state.curDifficulty;
		state.diffText.text = '< ' + CoolUtil.difficultyString() + ' >';
		positionHighscore(state);
	}

	public static function positionHighscore(state:FreeplayState) {
		try {
			state.scoreText.x = FlxG.width - state.scoreText.width - 6;

			state.scoreBG.scale.x = FlxG.width - state.scoreText.x + 6;
			state.scoreBG.x = FlxG.width - (state.scoreBG.scale.x / 2);
			state.diffText.x = Std.int(state.scoreBG.x + (state.scoreBG.width / 2));
			state.diffText.x -= state.diffText.width / 2;
		}
		catch(e){}
	}

	public static function updateTexts(state:FreeplayState, elapsed:Float = 0.0)
	{
		state.lerpSelected = FlxMath.lerp(state.lerpSelected, FreeplayState.curSelected, FlxMath.bound(elapsed * 9.6, 0, 1));
		for (i in state._lastVisibles)
		{
			// The filter can rebuild the list between two frames, so an index
			// remembered last frame may already be gone.
			if (i >= state.grpSongs.members.length || i >= state.grpIcons.members.length) continue;
			state.grpSongs.members[i].visible = state.grpSongs.members[i].active = false;
			state.grpIcons.members[i].visible = state.grpIcons.members[i].active = false;
		}
		state._lastVisibles = [];

		var min:Int = Math.round(Math.max(0, Math.min(state.songs.length, state.lerpSelected - state._drawDistance)));
		var max:Int = Math.round(Math.max(0, Math.min(state.songs.length, state.lerpSelected + state._drawDistance)));
		for (i in min...max)
		{
			var item:Alphabet = state.grpSongs.members[i];
			item.visible = item.active = true;
			item.x = ((item.targetY - state.lerpSelected) * item.distancePerItem.x) + item.startPosition.x;
			item.y = ((item.targetY - state.lerpSelected) * 1.3 * item.distancePerItem.y) + item.startPosition.y;

			var icon:HealthIcon = state.grpIcons.members[i];
			icon.visible = icon.active = true;
			state._lastVisibles.push(i);
		}
	}

	// Playback

	public static function playSong(state:FreeplayState) {
		if (state.songs.length == 0) return;
		#if PRELOAD_ALL
		destroyFreeplayVocals();
		FlxG.sound.music.volume = 0;
		Mods.currentModDirectory = state.songs[FreeplayState.curSelected].folder;
		var poop:String = Highscore.formatSong(state.songs[FreeplayState.curSelected].songName.toLowerCase(), state.curDifficulty);
		PlayState.SONG = Song.loadFromJson(poop, state.songs[FreeplayState.curSelected].songName.toLowerCase());

		var diff:String = (PlayState.SONG.specialAudioName.length > 1 ? PlayState.SONG.specialAudioName : CoolUtil.difficulties[state.curDifficulty]).toLowerCase();

		if (PlayState.SONG.needsVoices)
		{
			FreeplayState.vocals = new FlxSound();
			try
			{
				var playerVocals:String = getVocalFromCharacter(state, PlayState.SONG.player1);
				var loadedVocals:openfl.media.Sound = Paths.voices(PlayState.SONG.song, diff, (playerVocals != null && playerVocals.length > 0) ? playerVocals : 'Player');
				if(loadedVocals == null) loadedVocals = Paths.voices(PlayState.SONG.song, diff);

				if(loadedVocals != null && loadedVocals.length > 0)
				{
					FreeplayState.vocals.loadEmbedded(loadedVocals);
					FlxG.sound.list.add(FreeplayState.vocals);
					FreeplayState.vocals.persist = FreeplayState.vocals.looped = true;
					FreeplayState.vocals.volume = 0.8;
					FreeplayState.vocals.play();
					FreeplayState.vocals.pause();
				}
				else FreeplayState.vocals = FlxDestroyUtil.destroy(FreeplayState.vocals);
			}
			catch(e:Dynamic)
			{
				FreeplayState.vocals = FlxDestroyUtil.destroy(FreeplayState.vocals);
			}

			FreeplayState.opponentVocals = new FlxSound();
			try
			{
				//trace('please work...');
				var oppVocals:String = getVocalFromCharacter(state, PlayState.SONG.player2);
				var loadedVocals:openfl.media.Sound = Paths.voices(PlayState.SONG.song, diff, (oppVocals != null && oppVocals.length > 0) ? oppVocals : 'Opponent');

				if(loadedVocals != null && loadedVocals.length > 0)
				{
					FreeplayState.opponentVocals.loadEmbedded(loadedVocals);
					FlxG.sound.list.add(FreeplayState.opponentVocals);
					FreeplayState.opponentVocals.persist = FreeplayState.opponentVocals.looped = true;
					FreeplayState.opponentVocals.volume = 0.8;
					FreeplayState.opponentVocals.play();
					FreeplayState.opponentVocals.pause();
					//trace('it worked yaaay!!');
				}
				else FreeplayState.opponentVocals = FlxDestroyUtil.destroy(FreeplayState.opponentVocals);
			}
			catch(e:Dynamic)
			{
				//trace('FUUUCK');
				FreeplayState.opponentVocals = FlxDestroyUtil.destroy(FreeplayState.opponentVocals);
			}
		}
		FlxG.sound.playMusic(Paths.inst(PlayState.SONG.song, diff), 0.7);
		if (FreeplayState.vocals != null)
		{
			FreeplayState.vocals.play();
			FreeplayState.vocals.persist = true;
			FreeplayState.vocals.looped = true;
			FreeplayState.vocals.volume = 0.7;
		}
		FreeplayState.instPlaying = FreeplayState.curSelected;
		Conductor.changeBPM(PlayState.SONG.bpm);
		for (funnyIcon in state.grpIcons.members)
			funnyIcon.canBounce = false;
		state.grpIcons.members[FreeplayState.instPlaying].canBounce = true;
		FreeplayState.curPlaying = true;
		#end

		if (FlxG.keys.pressed.SHIFT) {
			for (section in PlayState.SONG.notes) {
			state.noteCount += section.sectionNotes.length;
			state.requiredRamLoad += 72872 * section.sectionNotes.length;
			}
			CoolUtil.coolError("There are " + FlxStringUtil.formatMoney(state.noteCount, false) + " notes in this chart!\nWith Show Notes turned on, you'd need " + FlxStringUtil.formatBytes(state.requiredRamLoad / 2) + " of ram to load this.", "JS Engine Chart Diagnosis");
		}
		state.player.playingMusic = true;
		state.player.curTime = 0;
		state.player.switchPlayMusic();
		state.player.pauseOrResume(true);
	}

	public static function songJsonPopup(state:FreeplayState) { //you pressed space, but the song's ogg/mp3 files don't exist
		if (state.songs.length == 0) return;
		var poop:String = Highscore.formatSong(state.songs[FreeplayState.curSelected].songName.toLowerCase(), state.curDifficulty);
		trace(poop + '\'s .ogg/.mp3 does not exist!');
		FlxG.sound.play(Paths.sound('invalidJSON'));
		FlxG.camera.shake(0.05, 0.05);
		var funnyText = new FlxText(12, FlxG.height - 24, 0, "Invalid Song!");
		funnyText.scrollFactor.set();
		funnyText.screenCenter();
		funnyText.x = 5;
		funnyText.y = FlxG.height/2 - 64;
		funnyText.setFormat("vcr.ttf", 64, FlxColor.RED, FlxTextAlign.LEFT, FlxTextBorderStyle.OUTLINE, FlxColor.BLACK);
		state.add(funnyText);
		FlxTween.tween(funnyText, {alpha: 0}, 0.9, {
			onComplete: _ -> {
				state.remove(funnyText, true);
				funnyText.destroy();
			}
		});
	}

	public static function getVocalFromCharacter(state:FreeplayState, char:String)
	{
		try
		{
			var path:String = Paths.getPath('characters/$char.json', AssetType.TEXT);
			#if MODS_ALLOWED
			var character:Dynamic = Json.parse(File.getContent(path));
			#else
			var character:Dynamic = Json.parse(Assets.getText(path));
			#end
			return character.vocals_file;
		}
		catch (e:Dynamic) {}
		return null;
	}

	public static function destroyFreeplayVocals() {
		if(FreeplayState.vocals != null) FreeplayState.vocals.stop();
		FreeplayState.vocals = FlxDestroyUtil.destroy(FreeplayState.vocals);

		if(FreeplayState.opponentVocals != null) FreeplayState.opponentVocals.stop();
		FreeplayState.opponentVocals = FlxDestroyUtil.destroy(FreeplayState.opponentVocals);
	}
}