package play.helpers;

import flixel.util.FlxSort;
import backend.Achievements;
import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;
import backend.Highscore;
#if MODS_ALLOWED
#end
import backend.WeekData;

import debug.PoolStats;

import objects.Note;
import objects.Popup;
import objects.TimingPopup;
import play.objects.MissCounter;

import play.PlayState;

import psychlua.EtternaFunctions;

import play.helpers.HitTiming;
import play.helpers.PlayStateNoteHelpers;
import play.helpers.PlayStatePlayback;

@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateRating
{
	/**
	 * Popup ordering comparator, cached once: the inline arrow used to allocate a
	 * closure on every judged note. (#88)
	 */
	static function comparePopupTime(a:Popup, b:Popup):Int
	{
		return FlxSort.byValues(FlxSort.ASCENDING, a.popTime, b.popTime);
	}

	/**
	 * Image key of an Early/Late label for the current ratings folder.
	 *
	 * @param state  the running PlayState (owns the pixel prefixes).
	 * @param timing `early` or `late`.
	 * @return the full `ratings/<style>/early` key, or `null` when the art is
	 *         missing from that folder.
	 */
	public static function timingAsset(state:PlayState, timing:String):Null<String>
	{
		if (!HitTiming.isTiming(timing)) return null;
		if (state.timingAssets.exists(timing)) return state.timingAssets.get(timing);
		final asset:String = state.pixelRatingPrefix + timing + state.pixelRatingSuffix;
		final resolved:Null<String> = Paths.imageExists(asset) ? asset : null;
		state.timingAssets.set(timing, resolved);
		return resolved;
	}

	public static function cachePopUpScore(state:PlayState)
	{
		if (PlayState.isPixelStage)
		{
			state.pixelRatingPrefix = 'pixelUI/';
			state.pixelRatingSuffix = '-pixel';
		}

		var normalRating:String = 'ratings/' + ClientPrefs.ratingType.toLowerCase().replace(' ', '-').trim() + '/';

		state.pixelRatingPrefix += normalRating;

		Paths.image(state.pixelRatingPrefix + "perfect" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "sick" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "good" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "bad" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "shit" + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + "miss" + state.pixelRatingSuffix);

		// Early/Late labels (Mic'd Up! port). Optional art: a folder without
		// `early`/`late` shows the rating alone, and the lookup is cached here so
		// judging a note never hits the filesystem.
		state.timingAssets.clear();
		for (timing in [HitTiming.EARLY, HitTiming.LATE])
		{
			final asset:Null<String> = timingAsset(state, timing);
			if (asset == null) continue;
			Paths.image(asset);
		}

		for (i in 0...10) Paths.image(state.pixelRatingPrefix + 'num' + i + state.pixelRatingSuffix);
		Paths.image(state.pixelRatingPrefix + 'numneg' + state.pixelRatingSuffix);
		if (Paths.fileExists('images/${normalRating}' + 'hitStrings.txt', TEXT))
			state.hitStrings = Mods.mergeAllTextsNamed('images/${normalRating}' + 'hitStrings.txt', null, false);

		if (Paths.fileExists('images/${normalRating}' + 'fcStrings.txt', TEXT))
			state.fcStrings = Mods.mergeAllTextsNamed('images/${normalRating}' + 'fcStrings.txt', null, false);
	}

	public static function judgeNote(state:PlayState, note:Note = null, ?miss:Bool = false)
	{
		if (note == null || !note.alive) return;
		if (state.daRating == null) state.daRating = state.ratingsData[0]; //because it likes being stupid
		// Botplay never gets a label (Mic'd Up! does the same): there is no player
		// timing to report, and a stale value would leak into the next script call.
		if (state.cpuControlled) state.hitTiming = HitTiming.NONE;
		else
		{
			// Signed difference, kept for the Early/Late label: noteDiff itself stays
			// absolute because the Windows and accuracy maths depend on that.
			state.noteTimingDiff = (note.strumTime - Conductor.songPosition + ClientPrefs.ratingOffset) / state.playbackRate;
			state.noteDiff = Math.abs(state.noteTimingDiff);
			state.hitTiming = miss ? HitTiming.NONE
				: HitTiming.classify(state.noteTimingDiff, Conductor.safeZoneOffset, ClientPrefs.earlyLateDeadzone);
			final wife:Float = EtternaFunctions.wife3(state.noteDiff, Conductor.timeScale);

			state.daRating = Conductor.judgeNote(note, state.noteDiff, state.cpuControlled, miss);
			if (state.sickOnly && (state.noteDiff > ClientPrefs.sickWindow || state.noteDiff < -ClientPrefs.sickWindow))
				state.doDeathCheck(true);

			if (miss) state.daRating.image = 'miss';
				else if (state.ratingsData[0].image == 'miss') state.ratingsData[0].image = !ClientPrefs.noMarvJudge ? 'perfect' : 'sick';

			if (!miss)
			{
				if (!ClientPrefs.complexAccuracy) state.totalNotesHit += state.daRating.ratingMod;
				if (ClientPrefs.complexAccuracy) state.totalNotesHit += wife;
				note.ratingMod = state.daRating.ratingMod;
				if(!note.ratingDisabled) state.daRating.increase();
			}
			note.rating = state.daRating.name;
			note.hitTiming = state.hitTiming;
		}

		if(state.daRating.noteSplash && !note.noteSplashDisabled && !miss && state.splashesPerFrame[1] <= 4)
			PlayStateNoteHelpers.spawnNoteSplashOnNote(state, false, note);

		if(!state.practiceMode && !miss) {
			state.songScore += state.daRating.score * (PlayState.opponentChart ? state.polyphonyOppo : state.polyphonyBF);
			if(!state.cpuControlled && !note.ratingDisabled)
			{
				state.songHits++;
				state.totalPlayed++;
				if(!state.cpuControlled || state.cpuControlled) {
					RecalculateRating(state, false);
				}
			}
		}
	}

	public static function popUpScore(state:PlayState, note:Note = null, ?miss:Bool = false):Void
	{
		state.popUpsFrame += 1;

		if(ClientPrefs.scoreZoom && state.scoreTxt != null && !state.cpuControlled && !miss)
		{
			if(state.scoreTxtTween != null) {
				state.scoreTxtTween.cancel();
			}
			state.scoreTxt.scale.x = 1.075;
			state.scoreTxt.scale.y = 1.075;
			state.scoreTxtTween = FlxTween.tween(state.scoreTxt.scale, {x: 1, y: 1}, 0.2, {
				onComplete: function(twn:FlxTween) {
					state.scoreTxtTween = null;
				}
			});
		}

		if (!miss && !state.ffmpegMode) (PlayState.opponentChart ? state.opponentVocals : state.vocals).volume = PlayStatePlayback.vocalsVolume(state);

		judgeNote(state, note, miss);

		if (state.popUpsFrame <= 3)
		{
			if (!ClientPrefs.comboStacking)
			{
				// Kill in place instead of `remove(spr, true)`: splicing a popup out of the
				// group dropped it on the floor, so every rating/combo popup allocated a
				// fresh sprite. Killed members stay in the group for `recycle()`. (#88)
				for (spr in state.popUpGroup.members)
				{
					if (spr == null || !spr.exists) continue;
					FlxTween.cancelTweensOf(spr);
					spr.kill();
				}
				if (state.timingGroup != null)
				{
					for (label in state.timingGroup.members)
					{
						if (label == null || !label.exists) continue;
						FlxTween.cancelTweensOf(label);
						label.kill();
					}
				}
			}

			if (state.showRating && ClientPrefs.ratingPopups && !state.adaptiveRatingsDisabled && !ClientPrefs.simplePopups
				&& (!miss || (ClientPrefs.missRating && state.daRating != null))) {
				final pooled:Int = state.popUpGroup.length;
				state.rating = state.popUpGroup.recycle(Popup);
				PoolStats.spawn(PoolStats.POPUP, state.popUpGroup.length == pooled);
				state.rating.setupRating(state.pixelRatingPrefix + state.daRating.image + state.pixelRatingSuffix);
				state.rating.alphaTween();
				state.popUpGroup.insert(0, state.rating);
			}

			// Early/Late label (Mic'd Up! port). Only meaningful next to a rating
			// popup, so it follows that toggle; it has its own small pool because
			// it is drawn with its own acceleration/velocity, and reusing a combo
			// digit slot would leave a label behind on the next bad hit.
			spawnTiming(state, miss);

			if (state.showComboNum && ClientPrefs.comboPopups && !ClientPrefs.simplePopups)
			{
				final popupCombo:Float = miss && ClientPrefs.doidoMisses ? -state.missCounter.count : state.combo;
				final tempComboAlt:Float = Math.abs(popupCombo);
				MissCounter.digits(popupCombo, state.separatedScore);

				for (daLoop=>i in state.separatedScore)
				{
					final pooled:Int = state.popUpGroup.length;
					state.numScore = state.popUpGroup.recycle(Popup);
					PoolStats.spawn(PoolStats.POPUP, state.popUpGroup.length == pooled);
					state.numScore.setupNumber(state.pixelRatingPrefix + 'num' + i + state.pixelRatingSuffix, daLoop, tempComboAlt);
					state.numScore.color = MissCounter.color(popupCombo, ClientPrefs.doidoMisses, miss);
					state.numScore.alphaTween(true);
					state.popUpGroup.insert(0, state.numScore);
				}
			}

			if (ClientPrefs.showMS && !ClientPrefs.hideHud && state.daRating != null) {
				state.msTxt.showHit({
					noteDiff: state.noteDiff,
					combo: state.combo,
					rating: state.daRating.name,
					miss: miss,
					cpuControlled: state.cpuControlled,
					playbackRate: state.playbackRate
				});
			}

			if (ClientPrefs.ratingPopups && !state.adaptiveRatingsDisabled && ClientPrefs.simplePopups && !ClientPrefs.hideHud) {
				state.judgeTxt.showHit({
					combo: miss && ClientPrefs.doidoMisses ? -state.missCounter.count : state.combo,
					rating: state.daRating != null ? state.daRating.name : 'miss',
					miss: miss,
					timing: !miss && ClientPrefs.earlyLateRatings ? state.hitTiming : HitTiming.NONE,
					playbackRate: state.playbackRate
				});
			}
			if (ClientPrefs.ratingPopups && !ClientPrefs.simplePopups)
				state.popUpGroup.members.sort(comparePopupTime);
		}
	}

	/**
	 * Draws the Early/Late label for the note that was just judged.
	 *
	 * Silent unless the player enabled `earlyLateRatings`, the hit is not a miss,
	 * the rating sprites are on screen and the current ratings folder ships the
	 * art. `hitTiming` is already classified in `judgeNote()`.
	 *
	 * @param state running PlayState, used for its popup pool and pace.
	 * @param miss  whether this popup belongs to a missed note.
	 */
	public static function spawnTiming(state:PlayState, miss:Bool = false):Void
	{
		if (miss || !ClientPrefs.earlyLateRatings || ClientPrefs.hideHud) return;
		if (!ClientPrefs.ratingPopups || state.adaptiveRatingsDisabled || state.timingGroup == null || !state.showRating) return;

		final asset:Null<String> = timingAsset(state, state.hitTiming);
		if (asset == null) return;

		final pooled:Int = state.timingGroup.length;
		state.timingPopup = state.timingGroup.recycle(TimingPopup);
		PoolStats.spawn(PoolStats.POPUP, state.timingGroup.length == pooled);
		state.timingPopup.setup(asset);
		// Hug the rating popup that was just spawned; a missing/dead one falls back
		// to the centred HUD column inside place().
		final anchor:Popup = (state.rating != null && state.rating.exists && state.rating.visible) ? state.rating : null;
		state.timingPopup.place(anchor, ClientPrefs.comboOffset[0], ClientPrefs.comboOffset[1]);
		state.timingPopup.alphaTween();
		state.timingGroup.insert(0, state.timingPopup);
	}

	public static function updateScore(state:PlayState, miss:Bool = false)
	{
		state.scoreTxtUpdateFrame++;
		if (!state.scoreTxt.visible || state.scoreTxt == null)
			return;
		//GAH DAYUM THIS IS MORE OPTIMIZED THAN BEFORE
		//No it's not
		var divider = switch (ClientPrefs.scoreStyle)
		{
			case 'Leather Engine': '~';
			case 'Forever Engine': '•';
			default: '|';
		}
		state.formattedScore = PlayState.formatNumber(state.songScore);
		if (ClientPrefs.scoreStyle == 'JS Engine') state.formattedScore = PlayState.formatNumber(state.shownScore);
		state.formattedSongMisses = PlayState.formatNumber(state.songMisses);
		state.formattedCombo = PlayState.formatNumber(state.combo);
		state.formattedNPS = PlayState.formatNumber(state.nps);
		state.formattedMaxNPS = PlayState.formatNumber(state.maxNPS);
		state.npsString = state.showNPS ? ' $divider ' + (state.cpuControlled && ClientPrefs.botWatermark ? 'Bot ' : '') + 'NPS/Max: ' + state.formattedNPS + '/' + state.formattedMaxNPS : '';
		state.accuracy = Highscore.floorDecimal(state.ratingPercent * 100, 2) + '%';
		state.fcString = state.ratingFC;
		state.missString = (!state.instakillOnMiss ? switch(ClientPrefs.scoreStyle)
		{
			case 'Kade Engine', 'VS Impostor': ' $divider Combo Breaks: ' + state.formattedSongMisses;
			case 'Doki Doki+': ' $divider Breaks: ' + state.formattedSongMisses;
			default:
				' $divider Misses: ' + state.formattedSongMisses;
		} : '');

		state.botText = state.cpuControlled && ClientPrefs.botWatermark ? ' $divider Botplay Mode' : '';

		if (state.cpuControlled && ClientPrefs.botWatermark)
			state.tempScore = 'Bot Score: ' + state.formattedScore + (state.comboInfo ? ' $divider Bot Combo: ' + state.formattedCombo : '') + state.npsString + state.botText;

		else switch (ClientPrefs.scoreStyle)
		{
			case 'Kade Engine', 'Doki Doki+':
				state.tempScore = 'Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Accuracy: ' + state.accuracy + ' $divider (' + state.fcString + ') ' + state.ratingName;

			case "Dave Engine":
				state.tempScore = 'Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Accuracy: ' + state.accuracy + ' $divider ' + state.fcString;

			case "Forever Engine":
				state.tempScore = 'Score: ' + state.formattedScore + ' $divider Accuracy: ${state.accuracy} ['  + state.fcString + ']' + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Rank: ' + state.ratingName;

			case "Psych Engine", "JS Engine", "TGT V4":
				state.tempScore = 'Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Rating: ' + state.ratingName + (state.ratingName != '?' ? ' (${state.accuracy}) - ${state.fcString}' : '');

			case "Leather Engine":
				state.tempScore = '< Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Rating: ' + state.ratingName + (state.ratingName != '?' ? ' (${state.accuracy}) - ${state.fcString}' : '');

			case 'VS Impostor':
				state.tempScore = 'Score: ' + state.formattedScore + state.missString + (state.comboInfo ? ' $divider Combo: ' + state.formattedCombo : '') + state.npsString + ' $divider Accuracy: ${state.accuracy} ['  + state.fcString + ']';

			case 'Vanilla':
				state.tempScore = 'Score: ' + state.formattedScore;
		}

		state.scoreTxt.text = '${state.tempScore}\n';

		if (state.hasActiveScripts()) state.callOnLuas('onUpdateScore', [miss]);
	}

	public static function RecalculateRating(state:PlayState, badHit:Bool = false) {
		// Guard script variable publishing to avoid repeated method invocations and
		// Float-to-Dynamic boxing allocations on every judged note when no scripts are active.
		if (state.hasActiveScripts()) {
			state.setOnLuas('score', state.songScore);
			state.setOnLuas('misses', state.songMisses);
			state.setOnLuas('hits', state.songHits);
			state.setOnLuas('combo', state.combo);
		}
		if (badHit) state.missRecalcsPerFrame += 1;

		var ret:Dynamic = state.hasActiveScripts() ? state.callOnLuas('onRecalculateRating') : null;
		#if LUA_ALLOWED
		if(ret != FunkinLua.Function_Stop)
		#else
		if(true)
		#end
		{
			if(state.totalPlayed < 1) //Prevent divide by 0
				state.ratingName = '?';
			else
			{
				// Rating Percent
				state.ratingPercent = Math.min(1, Math.max(0, state.totalNotesHit / state.totalPlayed));

			if (Math.isNaN(state.ratingPercent))
				state.ratingString = '?';

				// Rating Name

				if (PlayState.ratingStuff.length <= 0) {
					state.ratingName = 'Error!';
				}
				else {
					if(state.ratingPercent >= 1)
					{
						state.ratingName = PlayState.ratingStuff[PlayState.ratingStuff.length-1][0]; //Uses last string
					}
					else
					{
						for (i in 0...PlayState.ratingStuff.length-1)
						{
							if(state.ratingPercent < PlayState.ratingStuff[i][1])
							{
								state.ratingName = PlayState.ratingStuff[i][0];
								break;
							}
						}
					}
				}
			}

			/**
			 * - Rating FC and other stuff -
			 *
			 * > Now with better evaluation instead of using regular spaghetti code
			 *
			 * # @Equinoxtic was here, hi :3
			 */

			final fcConditions:Array<Bool> = [
				(state.totalPlayed == 0), // 'No Play'
				(state.perfects > 0), // 'PFC'
				(state.sicks > 0), // 'SFC'
				(state.goods > 0), // 'GFC'
				(state.bads > 0), // 'BFC'
				(state.poorRatings > 0), // 'FC'
				(state.songMisses > 0 && state.songMisses < 10), // 'SDCB'
				(state.songMisses >= 10), // 'Clear'
				(state.songMisses >= 100), // 'TDCB'
				(state.songMisses >= 1000) // 'QDCB'
			];

			var cond:Int = fcConditions.length - 1;
			state.ratingFC = "";
			while (cond >= 0)
			{
				if (fcConditions[cond]) {
					state.ratingFC = state.fcStrings[cond];
					break;
				}
				cond--;
			}

			// basically same stuff, doesn't update every frame but it also means no memory leaks during botplay
			if (state.scoreTxt != null)
				updateScore(state, badHit);
		}

		if (state.hasActiveScripts()) {
			state.setOnLuas('rating', state.ratingPercent);
			state.setOnLuas('ratingName', state.ratingName);
			state.setOnLuas('ratingFC', state.ratingFC);
		}
	}

	public static function updateNps(state:PlayState)
	{
		if (ClientPrefs.showNPS && (state.notesHitDateArray.length > 0 || state.oppNotesHitDateArray.length > 0)) {
			var threshold = Conductor.songPosition - 1000 * state.npsSpeedMult;

			// notesHitDateArray
			var i = 0;
			var len = state.notesHitDateArray.length;
			while (i < len) {
				if (Math.isNaN(state.notesHitDateArray[i]) || state.notesHitDateArray[i] < threshold) {
					i++;
				} else {
					break;
				}
			}
			state.notesToRemoveCount = i;

			if (state.notesToRemoveCount > 0) {
				state.notesHitDateArray.splice(0, state.notesToRemoveCount);
				state.notesHitArray.splice(0, state.notesToRemoveCount);
			}

			state.nps = 0;
			for (value in state.notesHitArray)
				state.nps += value;

			// oppNotesHitDateArray
			i = 0;
			len = state.oppNotesHitDateArray.length;
			while (i < len) {
				if (Math.isNaN(state.oppNotesHitDateArray[i]) || state.oppNotesHitDateArray[i] < threshold) {
					i++;
				} else {
					break;
				}
			}
			state.oppNotesToRemoveCount = i;

			if (state.oppNotesToRemoveCount > 0) {
				state.oppNotesHitDateArray.splice(0, state.oppNotesToRemoveCount);
				state.oppNotesHitArray.splice(0, state.oppNotesToRemoveCount);
			}

			state.oppNPS = 0;
			for (value in state.oppNotesHitArray) {
				state.oppNPS += value;
			}

			if (state.oppNPS > state.maxOppNPS) {
				state.maxOppNPS = state.oppNPS;
			}
			if (state.nps > state.maxNPS) {
				state.maxNPS = state.nps;
			}

if (state.scoreTxtUpdateFrame <= 8 && state.scoreTxt != null) state.updateScore();
		}
	}

	#if ACHIEVEMENTS_ALLOWED
	public static function checkForAchievement(state:PlayState, achievesToCheck:Array<String> = null)
	{
		if(PlayState.chartingMode || state.trollingMode) return;

		var usedPractice:Bool = (state.practiceMode || state.cpuControlled);
		if(state.cpuControlled) return;

		for (name in achievesToCheck) {
			if(!Achievements.exists(name)) continue;

			var unlock:Bool = false;
			if (name != WeekData.getWeekFileName() + '_nomiss') // common achievements
			{
				switch(name)
				{
					case 'ur_bad':
						unlock = (state.ratingPercent < 0.2 && !state.practiceMode);

					case 'ur_good':
						unlock = (state.ratingPercent >= 1 && !usedPractice);

					case 'oversinging':
						unlock = (state.boyfriend.holdTimer >= 10 && !usedPractice);

					case 'hype':
						unlock = (!state.boyfriendIdled && !usedPractice);

					case 'two_keys':
						unlock = (!usedPractice && state.keysPressed.length <= 2);

					case 'toastie':
						unlock = (!ClientPrefs.cacheOnGPU && !ClientPrefs.shaders && ClientPrefs.lowQuality && !ClientPrefs.globalAntialiasing);

					case 'debugger':
						unlock = (state.songName == 'test' && !usedPractice);
				}
			}
			else // any FC achievements, name should be "weekFileName_nomiss", e.g: "week3_nomiss";
			{
				if(PlayState.isStoryMode && PlayState.campaignMisses + state.songMisses < 1 && CoolUtil.currentDifficulty.toUpperCase() == 'HARD'
					&& PlayState.storyPlaylist.length <= 1 && !PlayState.changedDifficulty && !usedPractice)
					unlock = true;
			}

			if(unlock) Achievements.unlock(name);
		}
	}
	#end
}
