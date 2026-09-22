package backend;

import data.Song.SwagSong;
import objects.Note;
import play.PlayState;

import data.Section;
import objects.NoteSplash;

typedef BPMChangeEvent =
{
	var stepTime:Int;
	var songTime:Float;
	var bpm:Float;
	@:optional var stepCrochet:Float;
}

class Conductor
{
	public static var bpm:Float = 100;
	public static var crochet:Float = ((60 / bpm) * 1000); // beats in milliseconds
	public static var stepCrochet:Float = crochet / 4; // steps in milliseconds
	public static var songPosition:Float=0;
	public static var offset:Float = 0;

	//public static var safeFrames:Int = 10;
	// credits to duskiewhy for making this
	public static var safeZoneOffset:Float = (ClientPrefs.safeFrames / 60) * 1000; // is calculated in create(), is safeFrames in milliseconds
	public static var timeScale:Float = Conductor.safeZoneOffset / 180; //max hit window should be 180 right?
	public static var ROWS_PER_BEAT = 48; // from Stepmania
	public static var BEATS_PER_MEASURE = 4; // TODO: time sigs
	public static var ROWS_PER_MEASURE = ROWS_PER_BEAT * BEATS_PER_MEASURE; // from Stepmania
	public static var MAX_NOTE_ROW = 1 << 30; // from Stepmania

	/**
	 * Executes the `beatToRow` operation.
	 * @param beat Input value for `beat`.
	 * @return Result produced by `beatToRow`, when applicable.
	 */
	public inline static function beatToRow(beat:Float):Int
		return Math.round(beat * ROWS_PER_BEAT);

	/**
	 * Executes the `rowToBeat` operation.
	 * @param row Input value for `row`.
	 * @return Result produced by `rowToBeat`, when applicable.
	 */
	public inline static function rowToBeat(row:Int):Float
		return row / ROWS_PER_BEAT;

	/**
	 * Executes the `secsToRow` operation.
	 * @param sex Input value for `sex`.
	 * @return Result produced by `secsToRow`, when applicable.
	 */
	public inline static function secsToRow(sex:Float):Int
		return Math.round(getBeat(sex) * ROWS_PER_BEAT);

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	/**
	 * Executes the `new` operation.
	 */
	public function new()
	{
	}

	/**
	 * Executes the `recalculateTimings` operation.
	 * @return Result produced by `recalculateTimings`, when applicable.
	 */
	public static function recalculateTimings()
	{
		Conductor.safeZoneOffset = Math.floor((ClientPrefs.safeFrames / 60) * 1000);
		Conductor.timeScale = Conductor.safeZoneOffset / 180;
	}

	/**
	 * Executes the `judgeNote` operation.
	 * @param note Input value for `note`.
	 * @param diff Input value for `diff`.
	 * @param botplay Input value for `botplay`.
	 * @param missedNote Input value for `missedNote`.
	 * @return Result produced by `judgeNote`, when applicable.
	 */
	public static function judgeNote(note:Note, diff:Float=0, ?botplay:Bool = false, ?missedNote:Bool = false):Rating // die
	{
		if (botplay || missedNote) return PlayState.instance.ratingsData[0];
		var data:Array<Rating> = PlayState.instance.ratingsData; //shortening cuz fuck u
		for(i in 0...data.length-1) //skips last window (Shit)
		{
			if (diff <= data[i].hitWindow)
			{
				return data[i];
			}
		}
		return data[data.length - 1];
	}

	/**
	 * Executes the `getCrotchetAtTime` operation.
	 * @param time Input value for `time`.
	 * @return Result produced by `getCrotchetAtTime`, when applicable.
	 */
	public static function getCrotchetAtTime(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepCrochet*4;
	}

	/**
	 * Executes the `getBPMFromSeconds` operation.
	 * @param time Input value for `time`.
	 * @return Result produced by `getBPMFromSeconds`, when applicable.
	 */
	public static function getBPMFromSeconds(time:Float){
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (time >= Conductor.bpmChangeMap[i].songTime)
				lastChange = Conductor.bpmChangeMap[i];
		}

		return lastChange;
	}

	/**
	 * Executes the `getBPMFromStep` operation.
	 * @param step Input value for `step`.
	 * @return Result produced by `getBPMFromStep`, when applicable.
	 */
	public static function getBPMFromStep(step:Float){
		var lastChange:BPMChangeEvent = {
			stepTime: 0,
			songTime: 0,
			bpm: bpm,
			stepCrochet: stepCrochet
		}
		for (i in 0...Conductor.bpmChangeMap.length)
		{
			if (Conductor.bpmChangeMap[i].stepTime<=step)
				lastChange = Conductor.bpmChangeMap[i];
		}

		return lastChange;
	}

	/**
	 * Executes the `beatToSeconds` operation.
	 * @param beat Input value for `beat`.
	 * @return Result produced by `beatToSeconds`, when applicable.
	 */
	public static function beatToSeconds(beat:Float): Float{
		var step = beat * 4;
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + ((step - lastChange.stepTime) / (lastChange.bpm / 60)/4) * 1000; // TODO: make less shit and take BPM into account PROPERLY
	}

	/**
	 * Executes the `getStep` operation.
	 * @param time Input value for `time`.
	 * @return Result produced by `getStep`, when applicable.
	 */
	public static function getStep(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	/**
	 * Executes the `getStepRounded` operation.
	 * @param time Input value for `time`.
	 * @return Result produced by `getStepRounded`, when applicable.
	 */
	public static function getStepRounded(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + Math.floor(time - lastChange.songTime) / lastChange.stepCrochet;
	}

	/**
	 * Executes the `getBeat` operation.
	 * @param time Input value for `time`.
	 * @return Result produced by `getBeat`, when applicable.
	 */
	public static function getBeat(time:Float){
		return getStep(time)/4;
	}

	/**
	 * Executes the `getBeatRounded` operation.
	 * @param time Input value for `time`.
	 * @return Result produced by `getBeatRounded`, when applicable.
	 */
	public static function getBeatRounded(time:Float):Int{
		return Math.floor(getStepRounded(time)/4);
	}

	/**
	 * Executes the `mapBPMChanges` operation.
	 * @param song Input value for `song`.
	 * @return Result produced by `mapBPMChanges`, when applicable.
	 */
	public static function mapBPMChanges(song:SwagSong)
	{
		bpmChangeMap = [];

		var curBPM:Float = song.bpm;
		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			if(song.notes[i].changeBPM && song.notes[i].bpm != curBPM)
			{
				curBPM = song.notes[i].bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM)/4
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = Math.round(getSectionBeats(song, i) * 4);
			totalSteps += deltaSteps;
			totalPos += ((60 / curBPM) * 1000 / 4) * deltaSteps;
		}
		if (bpmChangeMap.length > 0)
			trace("new BPM map BUDDY " + bpmChangeMap);
	}

	/**
	 * Executes the `getSectionBeats` operation.
	 * @param song Input value for `song`.
	 * @param section Input value for `section`.
	 * @return Result produced by `getSectionBeats`, when applicable.
	 */
	static function getSectionBeats(song:SwagSong, section:Int)
	{
		var val:Null<Float> = null;
		if(song.notes[section] != null) val = song.notes[section].sectionBeats;
		return val != null ? val : 4;
	}

	/**
	 * Executes the `calculateCrochet` operation.
	 * @param bpm Input value for `bpm`.
	 * @return Result produced by `calculateCrochet`, when applicable.
	 */
	inline public static function calculateCrochet(bpm:Float){
		return (60/bpm)*1000;
	}

	/**
	 * Executes the `changeBPM` operation.
	 * @param newBpm Input value for `newBpm`.
	 * @return Result produced by `changeBPM`, when applicable.
	 */
	public static function changeBPM(newBpm:Float)
	{
		bpm = newBpm;

		crochet = calculateCrochet(bpm);
		stepCrochet = crochet / 4;
	}
}

class Rating
{
	public var name:String = '';
	public var image:String = '';
	public var counter:String = '';
	public var hitWindow:Null<Float> = 0.0; //ms
	public var ratingMod:Float = 1;
	public var score:Int = 500;
	public var noteSplash:Bool = true;

	/**
	 * Executes the `new` operation.
	 * @param name Input value for `name`.
	 */
	public function new(name:String)
	{
		this.name = name;
		this.image = name;
		this.counter = name + 's';
		this.hitWindow = Reflect.field(ClientPrefs, name + 'Window');
		if(hitWindow == null)
		{
			hitWindow = 0;
		}
	}

	/**
	 * Executes the `loadDefault` operation.
	 * @return Result produced by `loadDefault`, when applicable.
	 */
	public static function loadDefault():Array<Rating>
	{
		var ratingsData:Array<Rating> = [];

		if (!ClientPrefs.noMarvJudge)
		{
			ratingsData.push(new Rating('perfect'));
		}

		var rating:Rating = new Rating('sick');
		rating.ratingMod = 1;
		rating.score = 350;
		rating.noteSplash = true;
		ratingsData.push(rating);

		var rating:Rating = new Rating('good');
		rating.ratingMod = 0.7;
		rating.score = 200;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('bad');
		rating.ratingMod = 0.4;
		rating.score = 100;
		rating.noteSplash = false;
		ratingsData.push(rating);

		var rating:Rating = new Rating('shit');
		rating.ratingMod = 0;
		rating.score = 50;
		rating.noteSplash = false;
		ratingsData.push(rating);
		return ratingsData;
	}
	
	/**
	 * Executes the `increase` operation.
	 * @param blah Input value for `blah`.
	 * @return Result produced by `increase`, when applicable.
	 */
	public function increase(blah:Int = 1)
	{
		Reflect.setField(PlayState.instance, counter, Reflect.field(PlayState.instance, counter) + blah);
	}
}
