package play.helpers;

import objects.DialogueBoxPsych;
import objects.DialogueBoxPsych.DialogueFile;

import objects.VideoSprite;

import play.PlayState;

import play.helpers.PlayStateCamera;
import play.helpers.PlayStateCountdown;
import play.helpers.PlayStatePlayback;
import play.helpers.PlayStateScripts;

// REFACTOR: imports for relocated root classes
import data.Song;

// REFACTOR: video / dialogue cutscene logic extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateCutscenes
{
	/**
	 * Executes the `startVideo` operation.
	 * @param state Input value for `state`.
	 * @param name Input value for `name`.
	 * @param library Input value for `library`.
	 * @return Result produced by `startVideo`, when applicable.
	 */
	public static function startVideo(state:PlayState, name:String, ?library:String = null, ?callback:Void->Void = null, forMidSong:Bool = false, canSkip:Bool = true, loop:Bool = false, playOnLoad:Bool = true)
	{
		#if VIDEOS_ALLOWED
		state.inCutscene = true;
		state.canPause = false;

		var foundFile:Bool = false;
		var fileName:String = Paths.video(name, library);

		#if sys
		if (FileSystem.exists(fileName))
		#else
		if (OpenFlAssets.exists(fileName))
		#end
		foundFile = true;

		if (foundFile)
		{
			state.videoCutscene = new VideoSprite(fileName, forMidSong, canSkip, loop);

			// Finish callback
			if (!forMidSong)
			{
				/**
				 * Executes the `onVideoEnd` operation.
				 * @return Result produced by `onVideoEnd`, when applicable.
				 */
				function onVideoEnd()
				{
					if (state.generatedMusic && PlayState.SONG.notes[Std.int(state.curStep / 16)] != null && !state.endingSong && !state.isCameraOnForcedPos)
					{
						PlayStateCamera.moveCameraSection(state);
						FlxG.camera.snapToTarget();
					}
					state.canPause = false;
					state.inCutscene = false;
					startAndEnd(state);
				}
				state.videoCutscene.finishCallback = (callback != null) ? callback.bind() : onVideoEnd;
				state.videoCutscene.onSkip = (callback != null) ? callback.bind() : onVideoEnd;
			}
			state.add(state.videoCutscene);

			if (playOnLoad)
				state.videoCutscene.videoSprite.play();
			return state.videoCutscene;
		}
		#if (LUA_ALLOWED)
		else PlayStateScripts.addTextToDebug(state, "Video not found: " + fileName, FlxColor.RED);
		#else
		else FlxG.log.error("Video not found: " + fileName);
		#end
		#else
		FlxG.log.warn('Platform not supported!');
		startAndEnd(state);
		#end
		return null;
	}

	/**
	 * Executes the `startAndEnd` operation.
	 * @param state Input value for `state`.
	 * @return Result produced by `startAndEnd`, when applicable.
	 */
	public static function startAndEnd(state:PlayState)
	{
		if(state.endingSong)
			PlayStatePlayback.endSong(state);
		else
			PlayStateCountdown.startCountdown(state);
	}

	/**
	 * Executes the `startDialogue` operation.
	 * @param state Input value for `state`.
	 * @param dialogueFile Input value for `dialogueFile`.
	 * @param song Input value for `song`.
	 */
	public static function startDialogue(state:PlayState, dialogueFile:DialogueFile, ?song:String = null):Void
	{
		// TO DO: Make this more flexible, maybe?
		if(state.psychDialogue != null) return;

		if(dialogueFile.dialogue.length > 0) {
			state.inCutscene = true;
			state.psychDialogue = new DialogueBoxPsych(dialogueFile, song);
			state.psychDialogue.scrollFactor.set();
			if(state.endingSong) {
				state.psychDialogue.finishThing = function() {
					state.psychDialogue = null;
					PlayStatePlayback.endSong(state);
				}
			} else {
				state.psychDialogue.finishThing = function() {
					state.psychDialogue = null;
					PlayStateCountdown.startCountdown(state);
				}
			}
			state.psychDialogue.nextDialogueThing = startNextDialogue.bind(state);
			state.psychDialogue.skipDialogueThing = skipDialogue.bind(state);
			state.psychDialogue.cameras = [state.camHUD];
			state.add(state.psychDialogue);
		} else {
			FlxG.log.warn('Your dialogue file is badly formatted!');
			startAndEnd(state);
		}
	}

	/**
	 * Executes the `startNextDialogue` operation.
	 * @param state Input value for `state`.
	 * @return Result produced by `startNextDialogue`, when applicable.
	 */
	public static function startNextDialogue(state:PlayState) {
		state.dialogueCount++;
		state.callOnLuas('onNextDialogue', [state.dialogueCount]);
	}

	/**
	 * Executes the `skipDialogue` operation.
	 * @param state Input value for `state`.
	 * @return Result produced by `skipDialogue`, when applicable.
	 */
	public static function skipDialogue(state:PlayState) {
		state.callOnLuas('onSkipDialogue', [state.dialogueCount]);
	}
}
