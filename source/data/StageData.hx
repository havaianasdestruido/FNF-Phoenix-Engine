package data;

import backend.Paths;
import backend.XmlDefinitions;

import data.Song.SwagSong;

typedef StageFile = {
	var directory:String;
	var defaultZoom:Float;
	@:optional var isPixelStage:Null<Bool>;
	var stageUI:String;

	var boyfriend:Array<Dynamic>;
	var girlfriend:Array<Dynamic>;
	var opponent:Array<Dynamic>;
	var hide_girlfriend:Bool;

	/**
	 * Shaders the stage renders with, compiled on the loading screen instead of
	 * on the first bop (see `shaders.ShaderWarmup`).
	 *
	 * Entries are either a built-in name (`shaders.ShaderWarmupRegistry`, e.g.
	 * `"rain"`, `"glitch"`) or a runtime shader from the active mod's
	 * `shaders/<name>.frag` (the same file Lua's `initShader` loads). Optional:
	 * stages created from Haxe code declare their instances through
	 * `BaseStage.declareShaders()` instead.
	 */
	@:optional var shaders:Array<String>;

	var camera_boyfriend:Array<Float>;
	var camera_opponent:Array<Float>;
	var camera_girlfriend:Array<Float>;
	var camera_speed:Null<Float>;
}

class StageData {
	public static function dummy():StageFile
	{
		return {
			directory: "",
			defaultZoom: 0.9,
			stageUI: "normal",

			boyfriend: [770, 100],
			girlfriend: [400, 130],
			opponent: [100, 100],
			hide_girlfriend: false,

			camera_boyfriend: [0, 0],
			camera_opponent: [0, 0],
			camera_girlfriend: [0, 0],
			camera_speed: 1,
		};
	}

	public static var forceNextDirectory:String = null;
	public static function loadDirectory(SONG:SwagSong) {
		var stage:String = '';
		if(SONG.stage != null)
			stage = SONG.stage;
		else if(Song.loadedSongName != null)
			stage = vanillaSongStage(Paths.formatToSongPath(Song.loadedSongName));
		else
			stage = 'stage';

		var stageFile:StageFile = getStageFile(stage);
		forceNextDirectory = (stageFile != null) ? stageFile.directory : ''; //preventing crashes
	}

	public static function vanillaSongStage(songName):String
	{
		// trace(songName);
		return switch (songName)
		{
			case 'spookeez' | 'south' | 'monster':
				'spooky';
			case 'pico' | 'blammed' | 'philly' | 'philly-nice':
				'philly';
			case 'milf' | 'satin-panties' | 'high':
				'limo';
			case 'cocoa' | 'eggnog':
				'mall';
			case 'winter-horrorland':
				'mallEvil';
			case 'senpai' | 'roses':
				'school';
			case 'thorns':
				'schoolEvil';
			case 'ugh' | 'guns' | 'stress':
				'tank';
			default:
				'stage';
		}
	}

	public static function getStageFile(stage:String):StageFile {
		var relativePath:String = 'stages/' + stage + '.json';
		var xmlRelativePath:String = 'stages/' + stage + '.xml';

		var rawText:String = null;
		var isXml:Bool = false;

		#if MODS_ALLOWED
		// Try the active mod's JSON first.
		var modPath:String = Paths.modFolders(relativePath);
		if(FileSystem.exists(modPath)) {
			rawText = File.getContent(modPath);
		}
		else {
			// Then the active mod's XML sibling.
			var xmlModPath:String = Paths.modFolders(xmlRelativePath);
			if(FileSystem.exists(xmlModPath)) {
				rawText = File.getContent(xmlModPath);
				isXml = true;
			}
		}
		#end

		if(rawText == null) {
			var path:String = Paths.getPath(relativePath, TEXT, null, true);

			#if MODS_ALLOWED
			if(FileSystem.exists(path))
				rawText = File.getContent(path);
			#else
			if(Assets.exists(path))
				rawText = Assets.getText(path);
			#end
		}

		// JSON missing: try the XML sibling before giving up.
		if(rawText == null && !isXml) {
			var xmlPath:String = Paths.getPath(xmlRelativePath, TEXT, null, true);
			#if MODS_ALLOWED
			if(FileSystem.exists(xmlPath)) {
				rawText = File.getContent(xmlPath);
				isXml = true;
			}
			#else
			if(Assets.exists(xmlPath)) {
				rawText = Assets.getText(xmlPath);
				isXml = true;
			}
			#end
		}

		if(rawText == null)
			return dummy();

		if(isXml) return cast XmlDefinitions.parseStage(rawText);
		return cast tjson.TJSON.parse(rawText);
	}

}
