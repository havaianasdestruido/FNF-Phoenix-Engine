package play;

import backend.MusicBeatState;

import objects.Character;
import objects.Note;
import objects.Note.EventNote;

import flixel.FlxBasic;

enum Countdown
{
	THREE;
	TWO;
	ONE;
	GO;
	START;
}

class BaseStage extends FlxBasic
{
	private var game(default, set):Dynamic = PlayState.instance;
	public var onPlayState:Bool = false;

	// some variables for convenience
	public var paused(get, never):Bool;
	public var songName(get, never):String;
	public var isStoryMode(get, never):Bool;
	public var seenCutscene(get, never):Bool;
	public var inCutscene(get, set):Bool;
	public var canPause(get, set):Bool;
	public var members(get, never):Dynamic;

	public var boyfriend(get, never):Character;
	public var dad(get, never):Character;
	public var gf(get, never):Character;
	public var boyfriendGroup(get, never):FlxSpriteGroup;
	public var dadGroup(get, never):FlxSpriteGroup;
	public var gfGroup(get, never):FlxSpriteGroup;

	public var camGame(get, never):FlxCamera;
	public var camHUD(get, never):FlxCamera;
	public var camOther(get, never):FlxCamera;

	public var defaultCamZoom(get, set):Float;
	public var camFollow(get, never):FlxPoint;
	public var camFollowPos(get, never):FlxObject;

	/**
	 * Executes the `new` operation.
*/
	public function new()
	{
		this.game = MusicBeatState.getState();
		if(this.game == null)
		{
			FlxG.log.warn('Invalid state for the stage added!');
			destroy();
		}
		else
		{
			this.game.stages.push(this);
			super();
			create();
		}
	}

	//main callbacks
	/**
	 * Executes the `create` operation.
	 * @return Result produced by `create`, when applicable.
	 */
	public function create() {}
	/**
	 * Executes the `createPost` operation.
	 * @return Result produced by `createPost`, when applicable.
	 */
	public function createPost() {}
	//public function update(elapsed:Float) {}
	/**
	 * Executes the `countdownTick` operation.
	 * @param count Input value for `count`.
	 * @param num Input value for `num`.
	 * @return Result produced by `countdownTick`, when applicable.
	 */
	public function countdownTick(count:Countdown, num:Int) {}
	/**
	 * Executes the `startSong` operation.
	 * @return Result produced by `startSong`, when applicable.
	 */
	public function startSong() {}

	// FNF steps, beats and sections
	public var curBeat:Int = 0;
	public var curDecBeat:Float = 0;
	public var curStep:Int = 0;
	public var curDecStep:Float = 0;
	public var curSection:Int = 0;
	/**
	 * Executes the `beatHit` operation.
	 * @return Result produced by `beatHit`, when applicable.
	 */
	public function beatHit() {}
	/**
	 * Executes the `stepHit` operation.
	 * @return Result produced by `stepHit`, when applicable.
	 */
	public function stepHit() {}
	/**
	 * Executes the `sectionHit` operation.
	 * @return Result produced by `sectionHit`, when applicable.
	 */
	public function sectionHit() {}

	// Substate close/open, for pausing Tweens/Timers
	/**
	 * Executes the `closeSubState` operation.
	 * @return Result produced by `closeSubState`, when applicable.
	 */
	public function closeSubState() {}
	/**
	 * Executes the `openSubState` operation.
	 * @param SubState Input value for `SubState`.
	 * @return Result produced by `openSubState`, when applicable.
	 */
	public function openSubState(SubState:FlxSubState) {}

	// Events
	/**
	 * Executes the `eventCalled` operation.
	 * @param eventName Input value for `eventName`.
	 * @param value1 Input value for `value1`.
	 * @param value2 Input value for `value2`.
	 * @param flValue1 Input value for `flValue1`.
	 * @param flValue2 Input value for `flValue2`.
	 * @param strumTime Input value for `strumTime`.
	 * @return Result produced by `eventCalled`, when applicable.
	 */
	public function eventCalled(eventName:String, value1:String, value2:String, flValue1:Null<Float>, flValue2:Null<Float>, strumTime:Float) {}
	/**
	 * Executes the `eventPushed` operation.
	 * @param event Input value for `event`.
	 * @return Result produced by `eventPushed`, when applicable.
	 */
	public function eventPushed(event:EventNote) {}
	/**
	 * Executes the `eventPushedUnique` operation.
	 * @param event Input value for `event`.
	 * @return Result produced by `eventPushedUnique`, when applicable.
	 */
	public function eventPushedUnique(event:EventNote) {}

	// Note Hit/Miss
	/**
	 * Executes the `goodNoteHit` operation.
	 * @param note Input value for `note`.
	 * @return Result produced by `goodNoteHit`, when applicable.
	 */
	public function goodNoteHit(note:Note) {}
	/**
	 * Executes the `opponentNoteHit` operation.
	 * @param note Input value for `note`.
	 * @return Result produced by `opponentNoteHit`, when applicable.
	 */
	public function opponentNoteHit(note:Note) {}
	/**
	 * Executes the `noteMiss` operation.
	 * @param note Input value for `note`.
	 * @return Result produced by `noteMiss`, when applicable.
	 */
	public function noteMiss(note:Note) {}
	/**
	 * Executes the `noteMissPress` operation.
	 * @param direction Input value for `direction`.
	 * @return Result produced by `noteMissPress`, when applicable.
	 */
	public function noteMissPress(direction:Int) {}

	// Game Over
	/**
	 * Executes the `onGameOver` operation.
	 * @return Result produced by `onGameOver`, when applicable.
	 */
	public function onGameOver() {}

	// Things to replace FlxGroup stuff and inject sprites directly into the state
	/**
	 * Executes the `add` operation.
	 * @param object Input value for `object`.
	 * @return Result produced by `add`, when applicable.
	 */
	function add(object:FlxBasic) game.add(object);
	/**
	 * Executes the `remove` operation.
	 * @param object Input value for `object`.
	 * @return Result produced by `remove`, when applicable.
	 */
	function remove(object:FlxBasic) game.remove(object);
	/**
	 * Executes the `insert` operation.
	 * @param position Input value for `position`.
	 * @param object Input value for `object`.
	 * @return Result produced by `insert`, when applicable.
	 */
	function insert(position:Int, object:FlxBasic) game.insert(position, object);

	/**
	 * Executes the `addBehindGF` operation.
	 * @param obj Input value for `obj`.
	 * @return Result produced by `addBehindGF`, when applicable.
	 */
	public function addBehindGF(obj:FlxBasic) insert(members.indexOf(game.gfGroup), obj);
	/**
	 * Executes the `addBehindBF` operation.
	 * @param obj Input value for `obj`.
	 * @return Result produced by `addBehindBF`, when applicable.
	 */
	public function addBehindBF(obj:FlxBasic) insert(members.indexOf(game.boyfriendGroup), obj);
	/**
	 * Executes the `addBehindDad` operation.
	 * @param obj Input value for `obj`.
	 * @return Result produced by `addBehindDad`, when applicable.
	 */
	public function addBehindDad(obj:FlxBasic) insert(members.indexOf(game.dadGroup), obj);
	/**
	 * Executes the `setDefaultGF` operation.
	 * @param name Input value for `name`.
	 * @return Result produced by `setDefaultGF`, when applicable.
	 */
	public function setDefaultGF(name:String) //Fix for the Chart Editor on Base Game stages
	{
		var gfVersion:String = PlayState.SONG.gfVersion;
		if(gfVersion == null || gfVersion.length < 1)
		{
			gfVersion = name;
			PlayState.SONG.gfVersion = gfVersion;
		}
	}

	//start/end callback functions
	/**
	 * Executes the `setStartCallback` operation.
	 * @return Result produced by `setStartCallback`, when applicable.
	 */
	public function setStartCallback(myfn:Void->Void)
	{
		if(!onPlayState) return;
		PlayState.instance.startCallback = myfn;
	}
	/**
	 * Executes the `setEndCallback` operation.
	 * @return Result produced by `setEndCallback`, when applicable.
	 */
	public function setEndCallback(myfn:Void->Void)
	{
		if(!onPlayState) return;
		PlayState.instance.endCallback = myfn;
	}

	// overrides
	/**
	 * Executes the `startCountdown` operation.
	 * @return Result produced by `startCountdown`, when applicable.
	 */
	function startCountdown()
	{
		if(onPlayState && !PlayState.instance.skipCountdown)
		{
			PlayState.instance.startCountdown();
			return true;
		}
		else return false;
	}
	/**
	 * Executes the `endSong` operation.
	 * @return Result produced by `endSong`, when applicable.
	 */
	function endSong()
	{
		if(onPlayState)
		{
			PlayState.instance.endSong();
			return true;
		}
		else return false;
	}
	/**
	 * Executes the `moveCameraSection` operation.
	 * @return Result produced by `moveCameraSection`, when applicable.
	 */
	function moveCameraSection() if(onPlayState) PlayState.instance.moveCameraSection();
	/**
	 * Executes the `moveCamera` operation.
	 * @param focus Input value for `focus`.
	 * @return Result produced by `moveCamera`, when applicable.
	 */
	function moveCamera(focus:String = 'bf') if(onPlayState) PlayState.instance.moveCamera(focus);
	/**
	 * Executes the `get_paused` operation.
	 * @return Result produced by `get_paused`, when applicable.
	 */
	inline private function get_paused() return game.paused;
	/**
	 * Executes the `get_songName` operation.
	 * @return Result produced by `get_songName`, when applicable.
	 */
	inline private function get_songName() return game.songName;
	/**
	 * Executes the `get_isStoryMode` operation.
	 * @return Result produced by `get_isStoryMode`, when applicable.
	 */
	inline private function get_isStoryMode() return PlayState.isStoryMode;
	/**
	 * Executes the `get_seenCutscene` operation.
	 * @return Result produced by `get_seenCutscene`, when applicable.
	 */
	inline private function get_seenCutscene() return PlayState.seenCutscene;
	/**
	 * Executes the `get_inCutscene` operation.
	 * @return Result produced by `get_inCutscene`, when applicable.
	 */
	inline private function get_inCutscene() return game.inCutscene;
	/**
	 * Executes the `set_inCutscene` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_inCutscene`, when applicable.
	 */
	inline private function set_inCutscene(value:Bool)
	{
		game.inCutscene = value;
		return value;
	}
	/**
	 * Executes the `get_canPause` operation.
	 * @return Result produced by `get_canPause`, when applicable.
	 */
	inline private function get_canPause() return game.canPause;
	/**
	 * Executes the `set_canPause` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_canPause`, when applicable.
	 */
	inline private function set_canPause(value:Bool)
	{
		game.canPause = value;
		return value;
	}
	/**
	 * Executes the `get_members` operation.
	 * @return Result produced by `get_members`, when applicable.
	 */
	inline private function get_members() return game.members;
	/**
	 * Executes the `set_game` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_game`, when applicable.
	 */
	inline private function set_game(value:MusicBeatState)
	{
		onPlayState = (Std.isOfType(value, PlayState));
		game = value;
		return value;
	}

	/**
	 * Executes the `get_boyfriend` operation.
	 * @return Result produced by `get_boyfriend`, when applicable.
	 */
	inline private function get_boyfriend():Character return game.boyfriend;
	/**
	 * Executes the `get_dad` operation.
	 * @return Result produced by `get_dad`, when applicable.
	 */
	inline private function get_dad():Character return game.dad;
	/**
	 * Executes the `get_gf` operation.
	 * @return Result produced by `get_gf`, when applicable.
	 */
	inline private function get_gf():Character return game.gf;

	/**
	 * Executes the `get_boyfriendGroup` operation.
	 * @return Result produced by `get_boyfriendGroup`, when applicable.
	 */
	inline private function get_boyfriendGroup():FlxSpriteGroup return game.boyfriendGroup;
	/**
	 * Executes the `get_dadGroup` operation.
	 * @return Result produced by `get_dadGroup`, when applicable.
	 */
	inline private function get_dadGroup():FlxSpriteGroup return game.dadGroup;
	/**
	 * Executes the `get_gfGroup` operation.
	 * @return Result produced by `get_gfGroup`, when applicable.
	 */
	inline private function get_gfGroup():FlxSpriteGroup return game.gfGroup;

	/**
	 * Executes the `get_camGame` operation.
	 * @return Result produced by `get_camGame`, when applicable.
	 */
	inline private function get_camGame():FlxCamera return game.camGame;
	/**
	 * Executes the `get_camHUD` operation.
	 * @return Result produced by `get_camHUD`, when applicable.
	 */
	inline private function get_camHUD():FlxCamera return game.camHUD;
	/**
	 * Executes the `get_camOther` operation.
	 * @return Result produced by `get_camOther`, when applicable.
	 */
	inline private function get_camOther():FlxCamera return game.camOther;

	/**
	 * Executes the `get_defaultCamZoom` operation.
	 * @return Result produced by `get_defaultCamZoom`, when applicable.
	 */
	inline private function get_defaultCamZoom():Float return PlayState.instance.defaultCamZoom;
	/**
	 * Executes the `set_defaultCamZoom` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_defaultCamZoom`, when applicable.
	 */
	inline private function set_defaultCamZoom(value:Float):Float
	{
		PlayState.instance.defaultCamZoom = value;
		return PlayState.instance.defaultCamZoom;
	}
	/**
	 * Executes the `get_camFollow` operation.
	 * @return Result produced by `get_camFollow`, when applicable.
	 */
	inline private function get_camFollow():FlxPoint return game.camFollow;
	/**
	 * Executes the `get_camFollowPos` operation.
	 * @return Result produced by `get_camFollowPos`, when applicable.
	 */
	inline private function get_camFollowPos():FlxObject return game.camFollowPos;
}
