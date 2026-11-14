package play.helpers;

import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;

import data.Section.SwagSection;
import data.Song;

import editors.ChartingState;

import objects.Character;
import objects.Character.Boyfriend;
import objects.Note;
import objects.Note.EventNote;
import objects.Note.PreloadedChartNote;

import openfl.system.System;

import play.PlayState;

import backend.MusicBeatState;

private typedef CharacterSkinChange = {time:Float, skin:String};

@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateChartLoader
{
	public static function generateSong(state:PlayState, ?startingPoint:Float = 0):Void
	{
		var offsetStart = (startingPoint > 0 ? 500 : 0);
		final startTime = haxe.Timer.stamp();
		final noteCutoff:Float = startingPoint + offsetStart;

		state.songSpeedType = ClientPrefs.getGameplaySetting('scrolltype','multiplicative');

		switch(state.songSpeedType)
		{
			case "multiplicative":
				state.songSpeed = PlayState.SONG.speed * ClientPrefs.getGameplaySetting('scrollspeed', 1);
			case "constant":
				state.songSpeed = ClientPrefs.getGameplaySetting('scrollspeed', 1);
		}

		state.ogSongSpeed = state.songSpeed;

		Conductor.changeBPM(PlayState.SONG.bpm);

		state.curSong = PlayState.SONG.song;

		var diff:String = (PlayState.SONG.specialAudioName != null && PlayState.SONG.specialAudioName.length > 1 ? PlayState.SONG.specialAudioName : CoolUtil.difficultyString()).toLowerCase();

		if (PlayState.SONG.windowName != null && PlayState.SONG.windowName != '')
			MusicBeatState.windowNamePrefix = PlayState.SONG.windowName;

		// Experimental Extreme streams supported native Vorbis stems. Paths falls
		// back to normal decoding for MP3, embedded assets and unsupported targets.
		final streamSongAudio:Bool = backend.LowMemory.policy().streamSongAudio;
		state.vocals = new FlxSound();
		state.opponentVocals = new FlxSound();
		try
		{
			if (PlayState.SONG.needsVoices)
			{
				var playerVocals = Paths.voices(state.curSong, diff, (state.boyfriend.vocalsFile == null || state.boyfriend.vocalsFile.length < 1) ? "Player" : state.boyfriend.vocalsFile, streamSongAudio);
				state.vocals.loadEmbedded(playerVocals != null ? playerVocals : Paths.voices(state.curSong, diff, null, streamSongAudio));

				var oppVocals = Paths.voices(state.curSong, diff, (state.dad.vocalsFile == null || state.dad.vocalsFile.length < 1) ? "Opponent" : state.dad.vocalsFile, streamSongAudio);
				if(oppVocals != null) state.opponentVocals.loadEmbedded(oppVocals);
			}
		}
		catch(e) {}

		state.vocals.pitch = state.opponentVocals.pitch = state.playbackRate;
		FlxG.sound.list.add(state.vocals);
		FlxG.sound.list.add(state.opponentVocals);
		state.inst = new FlxSound();
		try
		{
			state.inst.loadEmbedded(Paths.inst(PlayState.SONG.song, diff, streamSongAudio));
		}
		catch (e:Dynamic) {}
		FlxG.sound.list.add(state.inst);

		final noteData:Array<SwagSection> = PlayState.SONG.notes;

		var eventsToLoad:String = (PlayState.SONG.specialEventsName != null && PlayState.SONG.specialEventsName.length > 1 ? PlayState.SONG.specialEventsName : CoolUtil.difficultyString()).toLowerCase();

		final songName:String = Paths.formatToSongPath(PlayState.SONG.song);
		final eventsFile:String = Paths.songEvents(songName, eventsToLoad);
		final eventsPath:String = Paths.json(eventsFile);
		// Registered assets are not necessarily loose files on sys targets, and
		// the short song/events key itself is not a valid OpenFL asset id.
		if (OpenFlAssets.exists(eventsPath)
			#if sys || FileSystem.exists(eventsPath) #end
			#if MODS_ALLOWED || FileSystem.exists(Paths.modsJson(eventsFile)) #end) {
			var eventsData:Array<Dynamic> = Song.loadFromJson(Paths.songEvents(songName, eventsToLoad, true), songName).events;
			pushEventNotes(state, eventsData, noteCutoff);
		}
		pushEventNotes(state, PlayState.SONG.events, noteCutoff);

		// Chart sectionNotes are not necessarily time-sorted. Build small,
		// sorted per-side timelines rather than advancing a shared skin cursor
		// in chart-file order. Events at the same timestamp keep their order.
		final playerSkinChanges:Array<CharacterSkinChange> = [];
		final opponentSkinChanges:Array<CharacterSkinChange> = [];
		for (i in 0...state.charChangeTimes.length)
		{
			final name:String = state.charChangeNames[i];
			switch (state.charChangeTypes[i])
			{
				case 0:
					final character:Boyfriend = state.boyfriendMap.get(name);
					if (character != null) playerSkinChanges.push({time: state.charChangeTimes[i], skin: CharacterNoteSkin.resolve(character.noteskin, PlayState.isPixelStage)});
				case 1:
					final character:Character = state.dadMap.get(name);
					if (character != null) opponentSkinChanges.push({time: state.charChangeTimes[i], skin: CharacterNoteSkin.resolve(character.noteskin, PlayState.isPixelStage)});
			}
		}
		final initialPlayerSkin:String = CharacterNoteSkin.resolve(state.bfNoteskin, PlayState.isPixelStage);
		final initialOpponentSkin:String = CharacterNoteSkin.resolve(state.dadNoteskin, PlayState.isPixelStage);

		var currentBPMLol:Float = Conductor.bpm;
		var stepCrochet:Float = 15000 / currentBPMLol;
		var currentMultiplier:Float = 1;
		var gottaHitNote:Bool = false;
		var swagNote:PreloadedChartNote;
		var ghostNotesCleared:Int = 0;
		var charChangeIndex:Int = 0;
		var multiChangeIndex:Int = 0;
		final jackCount:Int = Std.int(state.jackingtime);
		final jackStep:Float = 15000 / PlayState.SONG.bpm;
		// TODO: Optimize and clean up this mess, maybe split into functions
		// this is absolute spaghetti code
		for (section in noteData) {
			if (section.changeBPM) {
				currentBPMLol = section.bpm;
				stepCrochet = 15000 / currentBPMLol;
			}

			final sectionNotes:Array<Dynamic> = section.sectionNotes;
			final sectionLength:Int = sectionNotes.length;
			final mustHitSection:Bool = section.mustHitSection;
			final altAnim:Bool = section.altAnim;
			final gfSection:Bool = section.gfSection;

			for (i in 0...sectionLength)
			{
				final songNotes:Array<Dynamic> = sectionNotes[i];

				if (songNotes[1] == -1)
					continue;

				final daStrumTime:Float = songNotes[0];
				// Events and spawned notes both receive the player's note offset.
				// Compare them in the same time domain when selecting skins.
				final notePlaybackTime:Float = daStrumTime + ClientPrefs.noteOffset;
				if (daStrumTime >= noteCutoff) {
					var daNoteData:Int = 0;
					if (!state.assignedFirstData && state.oneK)
					{
						state.firstNoteData = Std.int(songNotes[1] % 4);
						state.assignedFirstData = true;
					}
					if (!state.randomMode && !state.flip && !state.stairs && !state.waves) daNoteData = Std.int(songNotes[1] % 4);

					if (state.oneK) daNoteData = state.firstNoteData;

					if (state.randomMode) daNoteData = FlxG.random.int(0, 3);

					if (state.flip) daNoteData = Std.int(Math.abs((songNotes[1] % 4) - 3));

					if (state.stairs && !state.waves) {
						daNoteData = state.stair % 4;
						state.stair++;
					}

					if (state.waves) {
						switch (state.stair % 6) {
							case 0 | 1 | 2 | 3:
								daNoteData = state.stair % 6;
							case 4:
								daNoteData = 2;
							case 5:
								daNoteData = 1;
						}
						state.stair++;
					}

					gottaHitNote = (!PlayState.opponentChart ? songNotes[1] < 4 : songNotes[1] > 3) ? mustHitSection : !mustHitSection;

					if ((PlayState.bothSides || gottaHitNote) && songNotes[3] != 'Hurt Note') {
						state.totalNotes += 1;
					}
					if (!PlayState.bothSides && !gottaHitNote) {
						state.opponentNoteTotal += 1;
					}

					// Keep the existing bookkeeping for consumed event records;
					// actual skin selection below is independent of note order.
					while (charChangeIndex < state.charChangeTimes.length && notePlaybackTime >= state.charChangeTimes[charChangeIndex])
						charChangeIndex++;

					if (multiChangeIndex < state.multiChangeEvents[0].length && daStrumTime >= state.multiChangeEvents[0][multiChangeIndex])
					{
						currentMultiplier = state.multiChangeEvents[1][multiChangeIndex];
						multiChangeIndex++;
					}

					// Normalize legacy note types once per chart note, then reuse the
					// derived flags for the head, jacks and every sustain segment.
					final rawNoteType:Dynamic = songNotes.length > 3 ? songNotes[3] : null;
					final rawIsBool:Bool = Std.isOfType(rawNoteType, Bool);
					final typeIndex:Int = Std.isOfType(rawNoteType, Int) || Std.isOfType(rawNoteType, Float) ? Std.int(rawNoteType) : -1;
					final noteType:Dynamic = Std.isOfType(rawNoteType, String) ? rawNoteType
						: (typeIndex >= 0 && typeIndex < ChartingState.noteTypeList.length ? ChartingState.noteTypeList[typeIndex] : '');
					final rawAnimSuffix:String = (rawNoteType == 'Alt Animation' || altAnim ? '-alt' : '');
					final animSuffix:String = rawIsBool ? (rawNoteType || altAnim ? '-alt' : '') : rawAnimSuffix;
					final isHurt:Bool = rawNoteType == 'Hurt Note';
					final gfNote:Bool = rawNoteType == 'GF Sing' || (gfSection && songNotes[1] < 4);
					final noAnimation:Bool = rawNoteType == 'No Animation';
					// Character JSON may omit noteskin (including the built-in BF).
					// Empty means the chart's default skin.
					final selectedSkin:String = gottaHitNote
						? skinAt(notePlaybackTime, initialPlayerSkin, playerSkinChanges)
						: skinAt(notePlaybackTime, initialOpponentSkin, opponentSkinChanges);
					final noteskin:String = selectedSkin != null ? selectedSkin : '';

					swagNote = {
						strumTime: daStrumTime,
						noteData: daNoteData,
						mustPress: PlayState.bothSides || gottaHitNote,
						oppNote: (PlayState.opponentChart ? gottaHitNote : !gottaHitNote),
						noteType: noteType,
						animSuffix: animSuffix,
						noteskin: noteskin,
						gfNote: gfNote,
						noAnimation: noAnimation,
						noMissAnimation: noAnimation,
						sustainLength: songNotes[2],
						hitHealth: 0.023,
						missHealth: !isHurt ? 0.0475 : 0.3,
						wasHit: false,
						hitCausesMiss: isHurt,
						multSpeed: 1,
						multAlpha: 1,
						noteDensity: currentMultiplier,
						ignoreNote: isHurt && gottaHitNote
					};
					if (!PlayState.isPixelStage && swagNote.noteskin.length > 0)
					{
						final skinTexture:String = 'noteskins/' + swagNote.noteskin;
						if (!Paths.noteSkinFramesMap.exists(skinTexture)) inline Paths.initNote(skinTexture);
					}

					if (!state.noteTypeMap.exists(swagNote.noteType)) {
						state.noteTypeMap.set(swagNote.noteType, true);
					}

					state.unspawnNotes.push(swagNote);

					if (jackCount > 0) {
						for (j in 0...jackCount) {
							final jackNote:PreloadedChartNote = {
								strumTime: swagNote.strumTime + jackStep * (j + 1),
								noteData: swagNote.noteData,
								mustPress: swagNote.mustPress,
								oppNote: swagNote.oppNote,
								noteType: swagNote.noteType,
								animSuffix: rawAnimSuffix,
								noteskin: noteskin,
								gfNote: swagNote.gfNote,
								noAnimation: swagNote.noAnimation,
								noMissAnimation: swagNote.noMissAnimation,
								isSustainNote: false,
								isSustainEnd: false,
								parentST: 0,
								hitHealth: swagNote.hitHealth,
								missHealth: swagNote.missHealth,
								wasHit: false,
								multSpeed: 1,
								multAlpha: 1,
								noteDensity: currentMultiplier,
								hitCausesMiss: swagNote.hitCausesMiss,
								ignoreNote: swagNote.ignoreNote
							};
							state.unspawnNotes.push(jackNote);
						}
					}

					if (swagNote.sustainLength < 1) continue;

					final roundSus:Int = Math.round(swagNote.sustainLength / stepCrochet);
					if (roundSus > 0) {
						final sustainMissHealth:Float = !isHurt ? 0.0475 : 0.1;
						final sustainIgnore:Bool = isHurt && swagNote.mustPress;
						for (susNote in 0...roundSus + 1) {
							final sustainNote:PreloadedChartNote = {
								strumTime: daStrumTime + (stepCrochet * susNote),
								noteData: daNoteData,
								mustPress: PlayState.bothSides || gottaHitNote,
								oppNote: (PlayState.opponentChart ? gottaHitNote : !gottaHitNote),
								noteType: rawNoteType,
								animSuffix: rawAnimSuffix,
								noteskin: noteskin,
								gfNote: gfNote,
								noAnimation: noAnimation,
								noMissAnimation: noAnimation,
								isSustainNote: true,
								isSustainEnd: susNote == roundSus,
								parentST: swagNote.strumTime,
								parentSL: swagNote.sustainLength,
								hitHealth: 0.023,
								missHealth: sustainMissHealth,
								wasHit: false,
								multSpeed: 1,
								multAlpha: 1,
								noteDensity: currentMultiplier,
								hitCausesMiss: isHurt,
								ignoreNote: sustainIgnore
							};
							state.unspawnNotes.push(sustainNote);
						}
					}
				} else {
					final gottaHitNote:Bool = ((songNotes[1] < 4 && !PlayState.opponentChart)
						|| (songNotes[1] > 3 && PlayState.opponentChart) ? mustHitSection : !mustHitSection);
					if ((PlayState.bothSides || gottaHitNote) && songNotes[3] != 'Hurt Note') {
						state.totalNotes += 1;
						state.missCombo = 0;
						state.missCounter.hit();
						state.combo += 1;
						state.totalNotesPlayed += 1;
					}
					if (!PlayState.bothSides && !gottaHitNote) {
						state.opponentNoteTotal += 1;
						state.enemyHits += 1;
					}
				}
			}
			PlayState.sectionsLoaded += 1;
			state.notesLoadedRN += sectionLength;
			#if debug
			#if sys
			Sys.print('\rSection ${PlayState.sectionsLoaded} loaded! (' + state.notesLoadedRN + ' notes)');
			#end
			#end
		}

		// Consume the event queues without shifting their tails on every note.
		if (charChangeIndex > 0) {
			state.charChangeTimes.splice(0, charChangeIndex);
			state.charChangeNames.splice(0, charChangeIndex);
			state.charChangeTypes.splice(0, charChangeIndex);
		}
		if (multiChangeIndex > 0) {
			state.multiChangeEvents[0].splice(0, multiChangeIndex);
			state.multiChangeEvents[1].splice(0, multiChangeIndex);
		}

		state.bfNoteskin = initialPlayerSkin;
		state.dadNoteskin = initialOpponentSkin;

		if (ClientPrefs.noteColorStyle == 'Char-Based')
		{
			for (group in [state.notes, state.sustainNotes])
				for (note in group){
					if (note == null || !note.alive)
						continue;
					if (ClientPrefs.enableColorShader) note.updateRGBColors();
				}
		}
		// trace('["${SONG.song.toUpperCase()}" CHART INFO]: Ghost Notes Cleared: $ghostNotesCleared');
		state.unspawnNotes.sort((a, b) -> PlayStateEvents.sortByTime(state, a, b));
		state.eventNotes.sort((a, b) -> PlayStateEvents.sortByTime(state, a, b));
		state.generatedMusic = true;

		PlayState.sectionsLoaded = 0;

		final endTime = haxe.Timer.stamp();

		System.gc();

		final elapsedTime = endTime - startTime;

		#if debug
		#if sys
		Sys.print('\nDone! \n\nTime taken: ' + CoolUtil.formatTime(elapsedTime * 1000) + "\nAverage NPS while loading: " + Math.floor(state.notesLoadedRN / elapsedTime));
		#end
		#end
		state.notesLoadedRN = 0;
	}

	/** Last character skin at or before this note, including tied events. */
	private static function skinAt(time:Float, initial:String, changes:Array<CharacterSkinChange>):String
	{
		var lo:Int = 0;
		var hi:Int = changes.length;
		while (lo < hi)
		{
			final mid:Int = lo + Std.int((hi - lo) / 2);
			if (changes[mid].time <= time) lo = mid + 1;
			else hi = mid;
		}
		return lo > 0 ? changes[lo - 1].skin : initial;
	}

	private static function pushEventNotes(state:PlayState, eventsData:Array<Dynamic>, cutoff:Float):Void
	{
		for (event in eventsData)
		{
			final eventTime:Float = event[0];
			if (eventTime < cutoff) continue;

			final subEvents:Array<Dynamic> = event[1];
			for (subEvent in subEvents)
			{
				var note:EventNote = {
					strumTime: eventTime + ClientPrefs.noteOffset,
					event: subEvent[0],
					value1: subEvent[1],
					value2: subEvent[2]
				};
				state.eventNotes.push(note);
				PlayStateEvents.eventPushed(state, note);
			}
		}
	}
}
