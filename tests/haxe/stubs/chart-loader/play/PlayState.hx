package play;

import data.Song.SwagSong;
import flixel.sound.FlxSound;
import objects.Character;
import objects.Note.EventNote;
import objects.Note.PreloadedChartNote;
import play.objects.MissCounter;

class PlayState
{
  public static var SONG:SwagSong;
  public static var opponentChart:Bool = false;
  public static var bothSides:Bool = false;
  public static var sectionsLoaded:Int = 0;

  public var songSpeedType:String = '';
  public var songSpeed:Float = 1;
  public var ogSongSpeed:Float = 1;
  public var curSong:String = '';
  public var vocals:FlxSound;
  public var opponentVocals:FlxSound;
  public var inst:FlxSound;
  public var playbackRate:Float = 1;
  public var boyfriend:Boyfriend = new Boyfriend();
  public var dad:Character = new Character();
  public var boyfriendMap:Map<String, Boyfriend> = new Map();
  public var dadMap:Map<String, Character> = new Map();
  public var bfNoteskin:String = '';
  public var dadNoteskin:String = '';
  public var assignedFirstData:Bool = false;
  public var oneK:Bool = false;
  public var firstNoteData:Int = 0;
  public var randomMode:Bool = false;
  public var flip:Bool = false;
  public var stairs:Bool = false;
  public var waves:Bool = false;
  public var stair:Int = 0;
  public var totalNotes:Float = 0;
  public var opponentNoteTotal:Float = 0;
  public var combo:Int = 0;
  public var missCombo:Int = 0;
  public var missCounter:MissCounter = new MissCounter();
  public var totalNotesPlayed:Int = 0;
  public var enemyHits:Int = 0;
  public var charChangeTimes:Array<Float> = [];
  public var charChangeNames:Array<String> = [];
  public var charChangeTypes:Array<Int> = [];
  public var multiChangeEvents:Array<Array<Float>> = [[], []];
  public var jackingtime:Float = 0;
  public var unspawnNotes:Array<PreloadedChartNote> = [];
  public var noteTypeMap:Map<String, Bool> = new Map();
  public var notesLoadedRN:Int = 0;
  public var notes:Array<Dynamic> = [];
  public var sustainNotes:Array<Dynamic> = [];
  public var eventNotes:Array<EventNote> = [];
  public var generatedMusic:Bool = false;

  public function new() {}
}
