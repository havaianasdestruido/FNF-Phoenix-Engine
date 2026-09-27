package data;

import data.Section.SwagSection;
import backend.Conductor;
import backend.Paths;
import backend.CoolUtil;
import editors.ChartingState;
import haxe.format.JsonParser;

import objects.Note;


typedef SwagSong =
{
	var song:String;
	var notes:Array<SwagSection>;
	var events:Array<Dynamic>;
	var bpm:Float;
	var needsVoices:Bool;
	var speed:Float;

	var player1:String;
	var player2:String;
	var gfVersion:String;
	var stage:String;

	@:optional var gameOverChar:String;
	@:optional var gameOverSound:String;
	@:optional var gameOverLoop:String;
	@:optional var gameOverEnd:String;

	@:optional var disableNoteRGB:Bool;

	var songCredit:String;
	var songCreditBarPath:String;
	var songCreditIcon:String;
	var event7:String;
	var event7Value:String;

	var windowName:String;
	var specialAudioName:String;
	var specialEventsName:String;

	var arrowSkin:String;
	var splashSkin:String;
}

class Song
{
	public var song:String;
	public var notes:Array<SwagSection>;
	public var events:Array<Dynamic>;
	public var bpm:Float;
	public var needsVoices:Bool = true;
	public var arrowSkin:String;
	public var splashSkin:String;
	public var gameOverChar:String;
	public var gameOverSound:String;
	public var gameOverLoop:String;
	public var gameOverEnd:String;
	public var disableNoteRGB:Bool = false;
	public var speed:Float = 1;
	public var stage:String;
	public var player1:String = 'bf';
	public var player2:String = 'dad';
	public var gfVersion:String = 'gf';

	public static var psychV1Chart:Bool = false;

	private static function onLoadJson(songJson:Dynamic) // Convert old charts to newest format
	{
		if(songJson.events == null)
		{
			songJson.events = [];
			for (secNum in 0...songJson.notes.length)
			{
				var sec:SwagSection = songJson.notes[secNum];

				var i:Int = 0;
				var notes:Array<Dynamic> = sec.sectionNotes;
				var len:Int = notes.length;
				while(i < len)
				{
					var note:Array<Dynamic> = notes[i];
					if(note[1] < 0)
					{
						songJson.events.push([note[0], [[note[2], note[3], note[4]]]]);
						notes.remove(note);
						len = notes.length;
					}
					else i++;
				}
			}
		}
		
		//processes the chart if it's made in psych 1.0
		if (psychV1Chart) {
			var curBPM:Float = Conductor.bpm;
			var susDiff = 7500 / curBPM;
			var sectionsData:Array<SwagSection> = songJson.notes;
			if(sectionsData == null) return;

			for (section in sectionsData)
			{
				if (section.changeBPM) {
					curBPM = section.bpm;
					susDiff = 7500 / curBPM;
				}
				var beats:Null<Float> = cast section.sectionBeats;
				if (beats == null || Math.isNaN(beats))
				{
					section.sectionBeats = 4;
					if(Reflect.hasField(section, 'lengthInSteps')) Reflect.deleteField(section, 'lengthInSteps');
				}

				for (note in section.sectionNotes)
				{
					var gottaHitNote:Bool = (note[1] < 4) ? section.mustHitSection : !section.mustHitSection;
					note[1] = (note[1] % 4) + (gottaHitNote ? 0 : 4);

					//i'll figure out this part later but its because Psych 1.0 is weird with sustain lengths
					if (note[2] > 0) {
						note[2] -= susDiff;
						note[2] = Math.fround(note[2] / susDiff) * susDiff;
						note[2] = Math.max(note[2], 0);
					}

					if(!Std.isOfType(note[3], String)) note[3] = editors.ChartingState.noteTypeList[note[3]]; //Backward compatibility + compatibility with Week 7 charts

					if(Std.isOfType(note[3], Bool)) note[3] = (note[3] || section.altAnim ? 'Alt Animation' : ''); //Compatibility with charts made by SNIFF
				}
			}
		}
	}

	public static function hasDifficulty(songName:String, difficulty:String):Bool
	{
		var formattedSong:String = Paths.formatToSongPath(songName);
		var formDiff:String = Paths.formatToSongPath(difficulty);
		var jsonToFind:String = Paths.json(formattedSong + '/' + formattedSong + '-' + formDiff);
		#if MODS_ALLOWED
			if (!CoolUtil.defaultSongs.contains(formattedSong) && !CoolUtil.defaultSongsFormatted.contains(formattedSong))
				jsonToFind = Paths.modsJson(formattedSong + '/' + formattedSong + '-' + formDiff); #end
		#if sys
		if(FileSystem.exists(jsonToFind)) return true;
		#else
		if(OpenFlAssets.exists(jsonToFind)) return true;
		#end

		return false;
	}
	public static var loadedSongName:String;
	public static function loadFromJson(jsonInput:String, ?folder:String):SwagSong
	{
		if(folder == null) folder = jsonInput;
		var rawJson:String = null;
		
		loadedSongName = folder;

		var formattedFolder:String = Paths.formatToSongPath(folder);
		var formattedSong:String = Paths.formatToSongPath(jsonInput);
		#if MODS_ALLOWED
		var moddyFile:String = Paths.modsJson('$formattedFolder/$formattedSong');
		if(FileSystem.exists(moddyFile)) {
			rawJson = File.getContent(moddyFile).trim();
		}
		#end

		if(rawJson == null) {
			var path:String = Paths.json('$formattedFolder/$formattedSong');
			#if sys
			if(FileSystem.exists(path))
				rawJson = File.getContent(path);
			else
			#end
			{
				try {
					rawJson = Assets.getText(path);
				} catch (e:Dynamic) {
					rawJson = null;
				}
			}
		}

		if (rawJson == null) {
			// No chart found at all (e.g. content-stripped builds ship no
			// charts): hand back an empty dummy song instead of crashing.
		trace('Song "$folder/$jsonInput": chart not found, using an empty dummy chart.');
		psychV1Chart = false;
		// Use the song directory (not the difficulty-suffixed chart name) so
		// Inst/Voices lookups still resolve to the song's audio files.
		var dummy:SwagSong = dummySong(folder);
			if (jsonInput != 'events')
				StageData.loadDirectory(dummy);
			onLoadJson(dummy);
			return dummy;
		}

		var songJson:Dynamic = parseJSON(rawJson);
		if(jsonInput != 'events') StageData.loadDirectory(songJson);
		onLoadJson(songJson);
		return songJson;
	}

	/**
	 * Empty but fully valid song used when a chart file cannot be found.
	 * Keeps direct PlayState entry, the anti-cheat song swap and chart-less
	 * debug paths working in content-stripped (NO_BUILTIN_CONTENT) builds.
	 */
	public static function dummySong(?songName:String = 'test'):SwagSong
	{
		return {
			song: songName,
			notes: [],
			events: [],
			bpm: 150,
			needsVoices: false,
			speed: 1,
			player1: 'bf',
			player2: 'dad',
			gfVersion: 'gf',
			stage: 'stage',
			songCredit: '',
			songCreditBarPath: '',
			songCreditIcon: '',
			event7: '',
			event7Value: '',
			windowName: '',
			specialAudioName: '',
			specialEventsName: '',
			arrowSkin: '',
			splashSkin: 'noteSplashes'
		};
	}

	
	public static function parseJSON(rawJson:String):Dynamic {
		var songJson = cast Json.parse(rawJson);
		psychV1Chart = Reflect.hasField(songJson, 'format');
		if (psychV1Chart) {
			psychV1Chart = true;
			Reflect.deleteField(songJson, 'format');
			return songJson;
		}
		else return songJson.song;
	}
}
