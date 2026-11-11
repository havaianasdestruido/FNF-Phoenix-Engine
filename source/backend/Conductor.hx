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

	public inline static function beatToRow(beat:Float):Int
		return Math.round(beat * ROWS_PER_BEAT);

	public inline static function rowToBeat(row:Int):Float
		return row / ROWS_PER_BEAT;

	public inline static function secsToRow(sex:Float):Int
		return Math.round(getBeat(sex) * ROWS_PER_BEAT);

	public static var bpmChangeMap:Array<BPMChangeEvent> = [];

	public function new()
	{
	}

	public static function recalculateTimings()
	{
		Conductor.safeZoneOffset = Math.floor((ClientPrefs.safeFrames / 60) * 1000);
		Conductor.timeScale = Conductor.safeZoneOffset / 180;
	}

	public static function judgeNote(note:Note, diff:Float=0, ?botplay:Bool = false, ?missedNote:Bool = false):Rating // die
	{
		if (botplay || missedNote) return PlayState.instance.ratingsData[0];
		var data:Array<Rating> = PlayState.instance.ratingsData; //short name for the ratings list
		for(i in 0...data.length-1) //skips last window (Poor)
		{
			if (diff <= data[i].hitWindow)
			{
				return data[i];
			}
		}
		return data[data.length - 1];
	}

	public static function getCrotchetAtTime(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepCrochet*4;
	}

	public static function getBPMFromSeconds(time:Float){
		var map = Conductor.bpmChangeMap;
		var n = map.length;
		// bpmChangeMap is sorted ascending by songTime; binary search for the
		// rightmost entry with songTime <= time (O(log n) instead of O(n)).
		if (n == 0) {
			var lastChange:BPMChangeEvent = {
				stepTime: 0,
				songTime: 0.0,
				bpm: bpm,
				stepCrochet: stepCrochet
			};
			return lastChange;
		}
		var lo = 0;
		var hi = n - 1;
		var idx = -1;
		while (lo <= hi) {
			var mid = (lo + hi) >> 1;
			if (map[mid].songTime <= time) {
				idx = mid;
				lo = mid + 1;
			} else {
				hi = mid - 1;
			}
		}
		if (idx < 0) {
			var lastChange:BPMChangeEvent = {
				stepTime: 0,
				songTime: 0.0,
				bpm: bpm,
				stepCrochet: stepCrochet
			};
			return lastChange;
		}
		return map[idx];
	}

	public static function getBPMFromStep(step:Float){
		var map = Conductor.bpmChangeMap;
		var n = map.length;
		// bpmChangeMap is sorted ascending by stepTime; binary search for the
		// rightmost entry with stepTime <= step (O(log n) instead of O(n)).
		if (n == 0) {
			var lastChange:BPMChangeEvent = {
				stepTime: 0,
				songTime: 0.0,
				bpm: bpm,
				stepCrochet: stepCrochet
			};
			return lastChange;
		}
		var lo = 0;
		var hi = n - 1;
		var idx = -1;
		while (lo <= hi) {
			var mid = (lo + hi) >> 1;
			if (map[mid].stepTime <= step) {
				idx = mid;
				lo = mid + 1;
			} else {
				hi = mid - 1;
			}
		}
		if (idx < 0) {
			var lastChange:BPMChangeEvent = {
				stepTime: 0,
				songTime: 0.0,
				bpm: bpm,
				stepCrochet: stepCrochet
			};
			return lastChange;
		}
		return map[idx];
	}

	public static function beatToSeconds(beat:Float): Float{
		var step = beat * 4;
		var lastChange = getBPMFromStep(step);
		return lastChange.songTime + (step - lastChange.stepTime) * lastChange.stepCrochet;
	}

	public static function getStep(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + (time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getStepRounded(time:Float){
		var lastChange = getBPMFromSeconds(time);
		return lastChange.stepTime + Math.floor(time - lastChange.songTime) / lastChange.stepCrochet;
	}

	public static function getBeat(time:Float){
		return getStep(time)/4;
	}

	public static function getBeatRounded(time:Float):Int{
		return Math.floor(getStepRounded(time)/4);
	}

	public static function mapBPMChanges(song:SwagSong)
	{
		bpmChangeMap = [];
		// Store explicit tempo changes only; consumers provide their own base BPM fallback.

		var curBPM:Float = song.bpm;
		if (Math.isNaN(curBPM) || curBPM <= 0) curBPM = 100;

		var totalSteps:Int = 0;
		var totalPos:Float = 0;
		for (i in 0...song.notes.length)
		{
			var section = song.notes[i];
			if (section != null && section.changeBPM && !Math.isNaN(section.bpm) && section.bpm > 0 && section.bpm != curBPM)
			{
				curBPM = section.bpm;
				var event:BPMChangeEvent = {
					stepTime: totalSteps,
					songTime: totalPos,
					bpm: curBPM,
					stepCrochet: calculateCrochet(curBPM) / 4
				};
				bpmChangeMap.push(event);
			}

			var deltaSteps:Int = Math.round(getSectionBeats(song, i) * 4);
			totalSteps += deltaSteps;
			totalPos += (calculateCrochet(curBPM) / 4) * deltaSteps;
		}
	}

	static function getSectionBeats(song:SwagSong, section:Int):Float
	{
		var val:Null<Float> = null;
		if (song.notes[section] != null) val = song.notes[section].sectionBeats;
		return val != null && !Math.isNaN(val) && val > 0 ? val : 4;
	}

	inline public static function calculateCrochet(bpm:Float){
		return (60/bpm)*1000;
	}

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

	public function new(name:String)
	{
		this.name = name;
		this.image = name;
		// The lowest rating increments `poorRatings`, used by the FC conditions in
		// `PlayStateRating.RecalculateRating`. Keep this mapping explicit: deriving
		// a counter from the rating name would target a nonexistent field on hxcpp.
		this.counter = (name == 'shit') ? 'poorRatings' : name + 's';
		this.hitWindow = Reflect.field(ClientPrefs, name + 'Window');
		if(hitWindow == null)
		{
			hitWindow = 0;
		}
	}

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
	 * Counters that a `Rating.increase()` could not write to. Cached so a
	 * mod-defined rating with a bogus counter name costs one failed reflection
	 * instead of one per note.
	 */
	static var unwritableCounters:Map<String, Bool> = [];

	public function increase(blah:Int = 1)
	{
		var state = PlayState.instance;
		if (state == null) return;

		// hxcpp's Reflect.hasField() only answers for dynamic/anonymous
		// objects: for plain class fields it reports false even when the field
		// exists. The previous guard therefore skipped *every* built-in
		// counter -- "sicks", "perfects" and "goods" were never tallied and
		// each failed hit printed a trace ("Rating.increase: no PlayState
		// field for counter \"sicks\", skipping", 30 times in the 2026-11-11
		// bundle), so FC/accuracy readouts stayed at zero.
		// Add the built-in counters statically and keep reflection only for
		// ratings a mod registered, where a bad name is caught once and then
		// skipped for good.
		switch (counter)
		{
			case 'perfects': state.perfects += blah;
			case 'sicks': state.sicks += blah;
			case 'goods': state.goods += blah;
			case 'bads': state.bads += blah;
			case 'poorRatings': state.poorRatings += blah;
			default:
				if (unwritableCounters.exists(counter)) return;
				try
				{
					var current:Dynamic = Reflect.field(state, counter);
					Reflect.setField(state, counter, (current == null ? 0 : Std.int(current)) + blah);
				}
				catch (e:Dynamic)
				{
					// Reflect.setField() throws "Invalid field:<name>" on hxcpp
					// when the target has no such field. Report it once; losing
					// a counted hit must never take the game down mid-note.
					unwritableCounters.set(counter, true);
					trace('Rating.increase: PlayState has no counter "$counter", rating "$name" will not be tallied');
				}
		}
	}
}
