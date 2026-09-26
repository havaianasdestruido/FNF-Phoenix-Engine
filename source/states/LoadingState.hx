package states;

import backend.MusicBeatState;
import backend.Paths;
import data.StageData;
import flixel.util.typeLimit.NextState;
import haxe.io.Path;
import play.PlayState;

class LoadingState extends MusicBeatState {
	// TO DO: Make this easier

	/**
	 * Executes the `loadAndSwitchState` operation.
	 * @param target Input value for `target`.
	 * @param stopMusic Input value for `stopMusic`.
	 * @return Result produced by `loadAndSwitchState`, when applicable.
	 */
	public static function loadAndSwitchState(target:NextState, stopMusic = false) {
		FlxG.switchState(getNextState(target, stopMusic));
	}

	/**
	 * Executes the `getNextState` operation.
	 * @param target Input value for `target`.
	 * @param stopMusic Input value for `stopMusic`.
	 * @return Result produced by `getNextState`, when applicable.
	 */
	static function getNextState(target:NextState, stopMusic = false):NextState {
		var directory:String = 'shared';
		var weekDir:String = StageData.forceNextDirectory;
		StageData.forceNextDirectory = null;

		if(weekDir != null && weekDir.length > 0 && weekDir != '') directory = weekDir;

		Paths.setCurrentLevel(directory);
		trace('Setting asset folder to ' + directory);

		#if NO_PRELOAD_ALL
		var loaded:Bool = false;
		if (PlayState.SONG != null) {
			loaded = isSoundLoaded(Paths.inst(PlayState.SONG.song)) && (!PlayState.SONG.needsVoices || isSoundLoaded(Paths.voices(PlayState.SONG.song))) && isLibraryLoaded("shared") && isLibraryLoaded(directory);
		}

		if (!loaded)
			return new LoadingState(target, stopMusic, directory);
		#end
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();

		return target;
	}

	#if NO_PRELOAD_ALL
	/**
	 * Executes the `isSoundLoaded` operation.
	 * @param path Input value for `path`.
	 * @return Result produced by `isSoundLoaded`, when applicable.
	 */
	static function isSoundLoaded(path:String):Bool {
		return Assets.cache.hasSound(path);
	}

	/**
	 * Executes the `isLibraryLoaded` operation.
	 * @param library Input value for `library`.
	 * @return Result produced by `isLibraryLoaded`, when applicable.
	 */
	static function isLibraryLoaded(library:String):Bool {
		return Assets.getLibrary(library) != null;
	}
	#end
}
