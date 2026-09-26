package backend;

import Main;
import play.BaseStage;
import play.PlayState;
import shaders.CustomFadeTransition;
import backend.PsychCamera;
import mobile.MobileControls;
import mobile.flixel.FlxVirtualPad;
import flixel.input.actions.FlxActionInput;
import flixel.util.FlxDestroyUtil;
import flixel.addons.ui.FlxUIState;
#if !flash
import lime.app.Application;
#end

import data.Section;

class MusicBeatState extends FlxUIState
{
	private var curSection:Int = 0;
	private var stepsToDo:Int = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	private var oldStep:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	public static var camBeat:FlxCamera;

	/**
	 * Executes the `get_controls` operation.
	 * @return Result produced by `get_controls`, when applicable.
	 */
	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	var mobileControls:MobileControls;
	public var virtualPad:FlxVirtualPad;
	var trackedInputsMobileControls:Array<FlxActionInput> = [];
	var trackedInputsVirtualPad:Array<FlxActionInput> = [];

	/**
	 * Executes the `addVirtualPad` operation.
	 * @param DPad Input value for `DPad`.
	 * @param Action Input value for `Action`.
	 */
	public function addVirtualPad(DPad:FlxDPadMode, Action:FlxActionMode):Void
	{
		if (virtualPad != null)
			removeVirtualPad();

		virtualPad = new FlxVirtualPad(DPad, Action);
		add(virtualPad);

		controls.setVirtualPadUI(virtualPad, DPad, Action);
		trackedInputsVirtualPad = controls.trackedInputsUI;
		controls.trackedInputsUI = [];
	}

	/**
	 * Executes the `removeVirtualPad` operation.
	 */
	public function removeVirtualPad():Void
	{
		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);

		if (virtualPad != null)
			remove(virtualPad);
	}

	/**
	 * Executes the `addMobileControls` operation.
	 * @param DefaultDrawTarget Input value for `DefaultDrawTarget`.
	 */
	public function addMobileControls(DefaultDrawTarget:Bool = false):Void
	{
		if (mobileControls != null)
			removeMobileControls();

		mobileControls = new MobileControls();

		switch (MobileControls.mode)
		{
			case 'Hitbox':
				controls.setHitBox(mobileControls.hitbox);
			default:
				controls.setVirtualPadNOTES(mobileControls.virtualPad, RIGHT_FULL, NONE);
		}

		trackedInputsMobileControls = controls.trackedInputsNOTES;
		controls.trackedInputsNOTES = [];

		var camControls:FlxCamera = new FlxCamera();
		camControls.bgColor.alpha = 0;
		FlxG.cameras.add(camControls, DefaultDrawTarget);

		mobileControls.cameras = [camControls];
		mobileControls.visible = false;
		add(mobileControls);
	}

	/**
	 * Executes the `removeMobileControls` operation.
	 */
	public function removeMobileControls():Void
	{
		if (trackedInputsMobileControls.length > 0)
			controls.removeVirtualControlsInput(trackedInputsMobileControls);

		if (mobileControls != null)
			remove(mobileControls);
	}

	/**
	 * Executes the `addVirtualPadCamera` operation.
	 * @param DefaultDrawTarget Input value for `DefaultDrawTarget`.
	 */
	public function addVirtualPadCamera(DefaultDrawTarget:Bool = false):Void
	{
		if (virtualPad != null)
		{
			var camControls:FlxCamera = new FlxCamera();
			camControls.bgColor.alpha = 0;
			FlxG.cameras.add(camControls, DefaultDrawTarget);
			virtualPad.cameras = [camControls];
		}
	}

	/**
	 * Executes the `destroy` operation.
	 */
	override function destroy():Void
	{
		if (trackedInputsMobileControls.length > 0)
			controls.removeVirtualControlsInput(trackedInputsMobileControls);

		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);

		super.destroy();

		if (virtualPad != null)
			virtualPad = FlxDestroyUtil.destroy(virtualPad);

		if (mobileControls != null)
			mobileControls = FlxDestroyUtil.destroy(mobileControls);
	}

	var _psychCameraInitialized:Bool = false;

	public static var windowNameSuffix(default, set):String = "";
	public static var windowNameSuffix2(default, set):String = ""; //changes to "Outdated!" if the version of the engine is outdated
	public static var windowNamePrefix:String = "Friday Night Funkin' - Phoenix Engine";

	// better then updating it all the time which can cause memory leaks
	/**
	 * Executes the `set_windowNameSuffix` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_windowNameSuffix`, when applicable.
	 */
	static function set_windowNameSuffix(value:String){
		windowNameSuffix = value;
		#if !flash
		Application.current.window.title = windowNamePrefix + windowNameSuffix + windowNameSuffix2;
		#end
		return value;
	}
	/**
	 * Executes the `set_windowNameSuffix2` operation.
	 * @param value Input value for `value`.
	 * @return Result produced by `set_windowNameSuffix2`, when applicable.
	 */
	static function set_windowNameSuffix2(value:String){
		windowNameSuffix2 = value;
		#if !flash
		Application.current.window.title = windowNamePrefix + windowNameSuffix + windowNameSuffix2;
		#end
		return value;
	}
	public var variables:Map<String, Dynamic> = new Map<String, Dynamic>();
	/**
	 * Executes the `getVariables` operation.
	 * @return Result produced by `getVariables`, when applicable.
	 */
	public static function getVariables()
		return getState().variables;
	
	// this is just because FlxUIState has arguments in it's constructor
	/**
	 * Executes the `new` operation.
	 */
	public function new() {
		super();
	}

	/**
	 * Executes the `create` operation.
	 * @return Result produced by `create`, when applicable.
	 */
	override function create() {
		camBeat = FlxG.camera;
		var skip:Bool = FlxTransitionableState.skipNextTransOut;
		super.create();

		if(!_psychCameraInitialized && !Main.isPlayState()) initPsychCamera();

		if(!skip) {
			openSubState(new CustomFadeTransition(0.7, true));
		}
		FlxTransitionableState.skipNextTransOut = false;

		try {windowNamePrefix = Assets.getText(Paths.txt("windowTitleBase", "preload"));}
		catch(e) {}

		#if !flash
		Application.current.window.title = windowNamePrefix + windowNameSuffix + windowNameSuffix2;
		#end
	}

	/**
	 * Executes the `initPsychCamera` operation.
	 * @return Result produced by `initPsychCamera`, when applicable.
	 */
	public function initPsychCamera():PsychCamera
	{
		var camera = new PsychCamera();
		FlxG.cameras.reset(camera);
		FlxG.cameras.setDefaultDrawTarget(camera, true);
		_psychCameraInitialized = true;
		return camera;
	}

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		oldStep = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
		{
			stepHit();

			if(PlayState.SONG != null)
			{
				if (oldStep < curStep)
					updateSection();
				else
					rollbackSection();
			}
		}

		FlxG.autoPause = ClientPrefs.autoPause;

		stagesFunc(function(stage:BaseStage) {
			stage.update(elapsed);
		});

		super.update(elapsed);
	}

	/**
	 * Executes the `updateSection` operation.
	 */
	private function updateSection():Void
	{
		if(stepsToDo < 1) stepsToDo = Math.round(getBeatsOnSection() * 4);
		while(curStep >= stepsToDo)
		{
			curSection++;
			final beats:Float = getBeatsOnSection();
			stepsToDo += Math.round(beats * 4);
			sectionHit();
		}
	}

	/**
	 * Executes the `rollbackSection` operation.
	 */
	private function rollbackSection():Void
	{
		if(curStep < 0) return;

		final lastSection:Int = curSection;
		curSection = 0;
		stepsToDo = 0;
		for (i in 0...PlayState.SONG.notes.length)
		{
			if (PlayState.SONG.notes[i] != null)
			{
				stepsToDo += Math.round(getBeatsOnSection() * 4);
				if(stepsToDo > curStep) break;

				curSection++;
			}
		}

		if(curSection > lastSection) sectionHit();
	}

	/**
	 * Executes the `updateBeat` operation.
	 */
	private function updateBeat():Void
	{
		curBeat = Math.floor(curStep / 4);
		curDecBeat = curDecStep/4;
	}

	/**
	 * Executes the `updateCurStep` operation.
	 */
	private function updateCurStep():Void
	{
		final lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		final decimalStep = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + decimalStep;
		curStep = lastChange.stepTime + Math.floor(decimalStep);
		updateBeat();
	}

	/**
	 * Executes the `startOutro` operation.
*/
	override function startOutro(onOutroComplete:()->Void):Void
	{
		if (!FlxTransitionableState.skipNextTransIn)
		{
			openSubState(new CustomFadeTransition(0.6, false));
			CustomFadeTransition.finishCallback = onOutroComplete;
			return;
		}

		FlxTransitionableState.skipNextTransIn = false;

		onOutroComplete();
	}

	public var stages:Array<BaseStage> = [];
	//runs whenever the game hits a step
	/**
	 * Executes the `stepHit` operation.
*/
	public function stepHit():Void
	{
		//trace('Step: ' + curStep);
		stagesFunc(function(stage:BaseStage) {
			stage.curStep = curStep;
			stage.curDecStep = curDecStep;
			stage.stepHit();
		});

		if (curStep % 4 == 0)
			beatHit();
	}

	//runs whenever the game hits a beat
	/**
	 * Executes the `beatHit` operation.
*/
	public function beatHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curBeat = curBeat;
			stage.curDecBeat = curDecBeat;
			stage.beatHit();
		});
	}

	//runs whenever the game hits a section
	/**
	 * Executes the `sectionHit` operation.
*/
	public function sectionHit():Void
	{
		stagesFunc(function(stage:BaseStage) {
			stage.curSection = curSection;
			stage.sectionHit();
		});
	}

	/**
	 * Executes the `getState` operation.
	 * @return Result produced by `getState`, when applicable.
	 */
	public static function getState():MusicBeatState {
		return cast (FlxG.state, MusicBeatState);
	}

	/**
	 * Executes the `stagesFunc` operation.
	 * @return Result produced by `stagesFunc`, when applicable.
	 */
	function stagesFunc(func:BaseStage->Void)
	{
		for (stage in stages)
			if(stage != null && stage.exists && stage.active)
				func(stage);
	}

	/**
	 * Executes the `getBeatsOnSection` operation.
	 * @return Result produced by `getBeatsOnSection`, when applicable.
	 */
	function getBeatsOnSection()
	{
		var val:Null<Float> = 4;
		if(PlayState.SONG != null && PlayState.SONG.notes[curSection] != null) val = PlayState.SONG.notes[curSection].sectionBeats;
		return val == null ? 4 : val;
	}
}
