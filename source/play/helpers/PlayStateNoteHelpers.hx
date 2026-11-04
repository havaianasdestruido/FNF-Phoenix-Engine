package play.helpers;

import flixel.util.FlxSort;

import backend.ClientPrefs;
import backend.Conductor;
import backend.ScreenLayout;

import debug.PoolStats;

import objects.Character;
import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;

import play.objects.SustainSplash;

import play.PlayState;

import shaders.CrossFade;

// REFACTOR: note group/splash helpers extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateNoteHelpers
{
	/**
	 * Note groups are sorted twice per frame during gameplay, and
	 * `FlxTypedGroup.sort()` binds a brand new closure on every call. These two
	 * comparators are bound once at class-init time so the per-frame sort is
	 * allocation free. (#88)
	 */
	static function compareNoteY(order:Int, note1:Note, note2:Note):Int
	{
		return FlxSort.byValues(order, note1.y, note2.y);
	}

	static final notesAscending:Note->Note->Int = compareNoteY.bind(FlxSort.ASCENDING);
	static final notesDescending:Note->Note->Int = compareNoteY.bind(FlxSort.DESCENDING);

	/**
	 * Sorts one note group by `y` for the current scroll direction, reusing the
	 * cached comparator instead of allocating a closure like
	 * `FlxTypedGroup.sort()` does.
	 *
	 * @param group `PlayState.notes` or `PlayState.sustainNotes`.
	 */
	public static function sortNoteGroup(group:FlxTypedGroup<Note>):Void
	{
		if (group == null || group.length <= 1) return;
		group.members.sort(ClientPrefs.downScroll ? notesAscending : notesDescending);
	}

	public static function addBehindGF(state:PlayState, obj:FlxObject)
	{
		state.insert(state.members.indexOf(state.gfGroup), obj);
	}
	public static function addBehindBF(state:PlayState, obj:FlxObject)
	{
		state.insert(state.members.indexOf(state.boyfriendGroup), obj);
	}
	public static function addBehindDad(state:PlayState, obj:FlxObject)
	{
		state.insert(state.members.indexOf(state.dadGroup), obj);
	}

	public static function clearNotesBefore(state:PlayState, time:Float)
	{
		// #88: no `[state.notes, state.sustainNotes]` array per call — these run on every seek.
		clearGroupNotesBefore(state.notes, time);
		clearGroupNotesBefore(state.sustainNotes, time);
	}

	static function clearGroupNotesBefore(group:FlxTypedGroup<Note>, time:Float)
	{
		if (group == null) return;
		var i:Int = group.length - 1;
		while (i >= 0) {
			var daNote:Note = group.members[i];
			if(daNote.strumTime - 350 < time)
			{
				daNote.active = false;
				daNote.visible = false;
				daNote.ignoreNote = true;
				daNote.pendingKill = false;
				PoolStats.release(daNote.isSustainNote ? PoolStats.SUSTAIN : PoolStats.NOTE);
				group.remove(daNote, true);
			}
			--i;
		}
	}

	public static function KillNotes(state:PlayState) {
		killNoteGroup(state.notes);
		killNoteGroup(state.sustainNotes);
		//unspawnNotes = [];
		//eventNotes = [];
	}

	static function killNoteGroup(group:FlxTypedGroup<Note>)
	{
		if (group == null) return;
		while (group.length > 0)
		{
			final daNote:Note = group.members[0];
			if (daNote != null)
			{
				daNote.pendingKill = false;
				PoolStats.release(daNote.isSustainNote ? PoolStats.SUSTAIN : PoolStats.NOTE);
			}
			group.remove(daNote, true);
		}
	}

	/**
	 * Queues a note for recycling at the end of the frame.
	 *
	 * The `killNotes` array used to be scanned with `contains()` on every call,
	 * which is O(live notes) per note per frame; the queue membership now lives on
	 * the note itself. (#88)
	 */
	public static function invalidateNote(state:PlayState, note:Note):Void {
		if (note == null || note.pendingKill) return;
		note.pendingKill = true;
		state.killNotes.push(note);
	}

	/**
	 * Kills every queued note and empties the queue in place.
	 *
	 * Runs once per frame, so it must not allocate: the previous `killNotes = []`
	 * threw away a fresh array every frame and `iterator()` added another object
	 * on top. Killed notes stay group members with `exists == false`, which is
	 * exactly what `FlxTypedGroup.recycle()` picks up next time a note spawns.
	 */
	public static function destroyNotes(state:PlayState):Void
	{
		final killList:Array<Note> = state.killNotes;

		// shift() keeps the same array alive: `killNotes = []` used to allocate a
		// fresh array every frame, and `iterator()` allocated on top of it.
		while (killList.length > 0)
		{
			final noteKill:Note = killList.shift();
			if (noteKill == null) continue;

			noteKill.kill();
			noteKill.pendingKill = false; // cleared after kill() so nothing can re-queue mid-kill
			PoolStats.release(noteKill.isSustainNote ? PoolStats.SUSTAIN : PoolStats.NOTE);
		}
	}

	public static function spawnHoldSplashOnNote(state:PlayState, note:Note, ?isDad:Bool = false) {
		if (!ClientPrefs.noteSplashes || note == null || !note.alive)
			return;

		state.splashesPerFrame[(isDad ? 2 : 3)] += 1;

		if (note != null) {
			var strum:StrumNote = (isDad ? state.playerStrums : state.opponentStrums).members[note.noteData];
			final susLength:Float = (!note.isSustainNote ? note.sustainLength : note.parentSL);
			final tailLength:Int = Math.floor(susLength / Conductor.stepCrochet);

			if(strum != null && tailLength != 0)
				spawnHoldSplash(state, note);
		}
	}

	public static function spawnHoldSplash(state:PlayState, note:Note) {
		final group:FlxTypedGroup<SustainSplash> = state.grpHoldSplashes;
		final pooled:Int = group.length;
		var splash:SustainSplash = group.recycle(SustainSplash);
		// A grow/rotate pool only changes the group size when it had to construct. (#88)
		PoolStats.spawn(PoolStats.HOLD_SPLASH, group.length == pooled);
		splash.setupSusSplash((note.mustPress ? state.playerStrums : state.opponentStrums).members[note.noteData], note, state.playbackRate);
		note.noteHoldSplash = splash;
		group.add(splash);
	}

	public static function spawnNoteSplashOnNote(state:PlayState, isDad:Bool, note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			state.splashesPerFrame[(isDad ? 0 : 1)] += 1;
			final strum:StrumNote = !isDad ? state.playerStrums.members[note.noteData] : state.opponentStrums.members[note.noteData];
			if(strum != null)
				spawnNoteSplash(state, strum.x, strum.y, note.noteData, note);
		}
	}

	public static function spawnNoteSplash(state:PlayState, x:Float, y:Float, data:Int, ?note:Note = null) {
		final group:FlxTypedGroup<NoteSplash> = state.grpNoteSplashes;
		final pooled:Int = group.length;
		var splash:NoteSplash = group.recycle(NoteSplash);
		PoolStats.spawn(PoolStats.NOTE_SPLASH, group.length == pooled);
		splash.setupNoteSplash(x, y, data, note);
		group.add(splash);
	}

	/**
	 * Spawns a cross fade ghost out of its pool.
	 *
	 * Replaces the old `new CrossFade(...)` call sites, which allocated a sprite, a
	 * frames copy, an animation and a tween callback on every opponent note hit that
	 * carried the effect. (#88)
	 *
	 * @param group     one of `PlayState.grpCrossFade` / `grpGFCrossFade` / `grpBFCrossFade`.
	 * @param character the character to ghost.
	 * @param isDad     `true` on the opponent side of the strum line.
	 */
	public static function spawnCrossFade(group:FlxTypedGroup<CrossFade>, character:Character, ?isDad:Bool = true):Void
	{
		if (group == null || character == null) return;

		final pooled:Int = group.length;
		final fade:CrossFade = group.recycle(CrossFade);
		PoolStats.spawn(PoolStats.CROSS_FADE, group.length == pooled);

		// Characters that already draw a FlxTrail skip the effect; drop the pooled
		// instance again so it does not linger as a dead member.
		if (!fade.setup(character, isDad))
		{
			group.remove(fade, true);
			fade.destroy();
		}
	}

	public static function generateStaticArrows(state:PlayState, player:Int):Void
	{
		final strumLine:FlxPoint = FlxPoint.get(PlayState.middleScroll ? PlayState.STRUM_X_MIDDLESCROLL : PlayState.STRUM_X, (ClientPrefs.downScroll) ? FlxG.height - 150 : 50);
		for (i in 0...4)
		{
			var targetAlpha:Float = 1;
			if (player < 1)
			{
				if(!ClientPrefs.opponentStrums) targetAlpha = 0;
				else if(PlayState.middleScroll) targetAlpha = ClientPrefs.oppNoteAlpha;
			}

			final noteSkinExists:Bool = Paths.fileExists("images/noteskins/" + (player == 0 ? state.dadNoteskin : state.bfNoteskin) + '.png', IMAGE);

			var babyArrow:StrumNote = new StrumNote(strumLine.x, strumLine.y, i, player);
			babyArrow.downScroll = ClientPrefs.downScroll;
			if (noteSkinExists)
			{
				babyArrow.texture = "noteskins/" + (player == 0 ? state.dad.noteskin : state.boyfriend.noteskin);
				babyArrow.useRGBShader = false;
			}
			if (!PlayState.isStoryMode && !state.skipArrowStartTween)
			{
				babyArrow.alpha = 0;
				FlxTween.tween(babyArrow, {alpha: targetAlpha}, 1/(Conductor.bpm/240) / state.playbackRate, {ease: FlxEase.circOut, startDelay: 0.5 + (0.2 * i) / (Conductor.bpm/240) / state.playbackRate});
			}
			else
			{
				babyArrow.alpha = targetAlpha;
			}

			if (player == 1)
			{
				if (!PlayState.opponentChart || PlayState.opponentChart && PlayState.middleScroll) state.playerStrums.add(babyArrow);
				else state.opponentStrums.add(babyArrow);
			}
			else
			{
				if(PlayState.middleScroll)
				{
					babyArrow.x += 310;
					if(i > 1) { //Up and Right
						babyArrow.x += ScreenLayout.BASE_WIDTH / 2 + 25;
					}
				}
				if (!PlayState.opponentChart || PlayState.opponentChart && PlayState.middleScroll) state.opponentStrums.add(babyArrow);
				else state.playerStrums.add(babyArrow);
			}

			state.strumLineNotes.add(babyArrow);
			babyArrow.postAddedToGroup();
		}
		strumLine.put();
	}
}
