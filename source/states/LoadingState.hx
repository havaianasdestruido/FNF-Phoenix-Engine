package states;

import backend.MusicBeatState;
import backend.Paths;
import data.StageData;
import flixel.FlxG;
import flixel.util.typeLimit.NextState;
import haxe.io.Path;
import openfl.utils.Assets as OpenFlAssets;
import play.PlayState;

class LoadingState extends MusicBeatState {
	// TO DO: Make this easier

	public var target:NextState;
	public var stopMusic:Bool = false;
	public var directory:String = 'shared';

	public function new(target:NextState, stopMusic:Bool = false, directory:String = 'shared') {
		super();
		this.target = target;
		this.stopMusic = stopMusic;
		this.directory = directory;
	}

	public static function loadAndSwitchState(target:NextState, stopMusic = false) {
		FlxG.switchState(getNextState(target, stopMusic));
	}

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

	override function create() {
		super.create();

		#if NO_PRELOAD_ALL
		var libs:Array<String> = [];
		if (directory != null && directory.length > 0 && directory != 'shared') libs.push('shared');
		if (directory != null && directory.length > 0) libs.push(directory);
		if (libs.length == 0) libs = ['shared'];

		var remaining:Int = libs.length;
		var finish = function() {
			if (stopMusic && FlxG.sound.music != null)
				FlxG.sound.music.stop();
			FlxG.switchState(target);
		};

		for (lib in libs) {
			if (OpenFlAssets.getLibrary(lib) != null) {
				remaining--;
				if (remaining <= 0) finish();
			} else {
				OpenFlAssets.loadLibrary(lib, function(_) {
					remaining--;
					if (remaining <= 0) finish();
				});
			}
		}
		#else
		if (stopMusic && FlxG.sound.music != null)
			FlxG.sound.music.stop();
		FlxG.switchState(target);
		#end
	}

	#if NO_PRELOAD_ALL
	static function isSoundLoaded(path:String):Bool {
		return OpenFlAssets.cache.hasSound(path);
	}

	static function isLibraryLoaded(library:String):Bool {
		return OpenFlAssets.getLibrary(library) != null;
	}
	#end
}
