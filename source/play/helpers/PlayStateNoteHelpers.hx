package play.helpers;

import backend.ClientPrefs;
import backend.Conductor;

import objects.Note;
import objects.NoteSplash;
import objects.StrumNote;

import play.objects.SustainSplash;

import play.PlayState;

// REFACTOR: note group/splash helpers extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateNoteHelpers
{
	/**
	 * Executes the `addBehindGF` operation.
	 * @param state Input value for `state`.
	 * @param obj Input value for `obj`.
	 * @return Result produced by `addBehindGF`, when applicable.
	 */
	public static function addBehindGF(state:PlayState, obj:FlxObject)
	{
		state.insert(state.members.indexOf(state.gfGroup), obj);
	}
	/**
	 * Executes the `addBehindBF` operation.
	 * @param state Input value for `state`.
	 * @param obj Input value for `obj`.
	 * @return Result produced by `addBehindBF`, when applicable.
	 */
	public static function addBehindBF(state:PlayState, obj:FlxObject)
	{
		state.insert(state.members.indexOf(state.boyfriendGroup), obj);
	}
	/**
	 * Executes the `addBehindDad` operation.
	 * @param state Input value for `state`.
	 * @param obj Input value for `obj`.
	 * @return Result produced by `addBehindDad`, when applicable.
	 */
	public static function addBehindDad(state:PlayState, obj:FlxObject)
	{
		state.insert(state.members.indexOf(state.dadGroup), obj);
	}

	/**
	 * Executes the `clearNotesBefore` operation.
	 * @param state Input value for `state`.
	 * @param time Input value for `time`.
	 * @return Result produced by `clearNotesBefore`, when applicable.
	 */
	public static function clearNotesBefore(state:PlayState, time:Float)
	{
		for (group in [state.notes, state.sustainNotes])
		{
			var i:Int = group.length - 1;
			while (i >= 0) {
				var daNote:Note = group.members[i];
				if(daNote.strumTime - 350 < time)
				{
					daNote.active = false;
					daNote.visible = false;
					daNote.ignoreNote = true;
					group.remove(daNote, true);
				}
				--i;
			}
		}
	}

	/**
	 * Executes the `KillNotes` operation.
	 * @param state Input value for `state`.
	 * @return Result produced by `KillNotes`, when applicable.
	 */
	public static function KillNotes(state:PlayState) {
		for (group in [state.notes, state.sustainNotes]){
			if (group != null){
				while (group.length > 0) {
					group.remove(group.members[0], true);
				}
			}
		}
		//unspawnNotes = [];
		//eventNotes = [];
	}

	/**
	 * Executes the `invalidateNote` operation.
	 * @param state Input value for `state`.
	 * @param note Input value for `note`.
	 */
	public static function invalidateNote(state:PlayState, note:Note):Void {
		if (!state.killNotes.contains(note))
			state.killNotes.push(note);
	}

	/**
	 * Executes the `destroyNotes` operation.
	 * @param state Input value for `state`.
	 */
	public static function destroyNotes(state:PlayState):Void
	{
		final iterator:Iterator<Note> = state.killNotes.iterator();

		while (iterator.hasNext())
		{
			var noteKill:Note = iterator.next();
			noteKill.kill();
		}
		state.killNotes = [];
	}

	/**
	 * Executes the `spawnHoldSplashOnNote` operation.
	 * @param state Input value for `state`.
	 * @param note Input value for `note`.
	 * @param isDad Input value for `isDad`.
	 * @return Result produced by `spawnHoldSplashOnNote`, when applicable.
	 */
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

	/**
	 * Executes the `spawnHoldSplash` operation.
	 * @param state Input value for `state`.
	 * @param note Input value for `note`.
	 * @return Result produced by `spawnHoldSplash`, when applicable.
	 */
	public static function spawnHoldSplash(state:PlayState, note:Note) {
		var end:Note = note;
		var splash:SustainSplash = state.grpHoldSplashes.recycle(SustainSplash);
		splash.setupSusSplash((note.mustPress ? state.playerStrums : state.opponentStrums).members[note.noteData], note, state.playbackRate);
		state.grpHoldSplashes.add(end.noteHoldSplash = splash);
	}

	/**
	 * Executes the `spawnNoteSplashOnNote` operation.
	 * @param state Input value for `state`.
	 * @param isDad Input value for `isDad`.
	 * @param note Input value for `note`.
	 * @return Result produced by `spawnNoteSplashOnNote`, when applicable.
	 */
	public static function spawnNoteSplashOnNote(state:PlayState, isDad:Bool, note:Note) {
		if(ClientPrefs.noteSplashes && note != null) {
			state.splashesPerFrame[(isDad ? 0 : 1)] += 1;
			final strum:StrumNote = !isDad ? state.playerStrums.members[note.noteData] : state.opponentStrums.members[note.noteData];
			if(strum != null)
				spawnNoteSplash(state, strum.x, strum.y, note.noteData, note);
		}
	}

	/**
	 * Executes the `spawnNoteSplash` operation.
	 * @param state Input value for `state`.
	 * @param x Input value for `x`.
	 * @param y Input value for `y`.
	 * @param data Input value for `data`.
	 * @param note Input value for `note`.
	 * @return Result produced by `spawnNoteSplash`, when applicable.
	 */
	public static function spawnNoteSplash(state:PlayState, x:Float, y:Float, data:Int, ?note:Note = null) {
		var splash:NoteSplash = state.grpNoteSplashes.recycle(NoteSplash);
		splash.setupNoteSplash(x, y, data, note);
		state.grpNoteSplashes.add(splash);
	}

	/**
	 * Executes the `generateStaticArrows` operation.
	 * @param state Input value for `state`.
	 * @param player Input value for `player`.
	 */
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
						babyArrow.x += FlxG.width / 2 + 25;
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
