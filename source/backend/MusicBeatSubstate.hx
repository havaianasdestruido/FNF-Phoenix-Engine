package backend;

import flixel.FlxBasic;
import mobile.flixel.FlxVirtualPad;
import flixel.input.actions.FlxActionInput;
import flixel.util.FlxDestroyUtil;

class MusicBeatSubstate extends FlxSubState
{
	/**
	 * Executes the `new` operation.
*/
	public function new()
	{
		super();
	}

	private var lastBeat:Float = 0;
	private var lastStep:Float = 0;

	private var curStep:Int = 0;
	private var curBeat:Int = 0;

	var oldStep:Int = 0;

	private var curDecStep:Float = 0;
	private var curDecBeat:Float = 0;
	private var controls(get, never):Controls;

	/**
	 * Executes the `get_controls` operation.
	 * @return Result produced by `get_controls`, when applicable.
	 */
	inline function get_controls():Controls
		return PlayerSettings.player1.controls;

	public var virtualPad:FlxVirtualPad;
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
		if (trackedInputsVirtualPad.length > 0)
			controls.removeVirtualControlsInput(trackedInputsVirtualPad);

		super.destroy();

		if (virtualPad != null)
			virtualPad = FlxDestroyUtil.destroy(virtualPad);
	}

	/**
	 * Executes the `update` operation.
	 * @param elapsed Input value for `elapsed`.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update(elapsed:Float)
	{
		if (oldStep != curStep) oldStep = curStep;

		updateCurStep();
		updateBeat();

		if (oldStep != curStep && curStep > 0)
			stepHit();

		super.update(elapsed);
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
		var lastChange = Conductor.getBPMFromSeconds(Conductor.songPosition);

		var decimalStep = ((Conductor.songPosition - ClientPrefs.noteOffset) - lastChange.songTime) / lastChange.stepCrochet;
		curDecStep = lastChange.stepTime + decimalStep;
		curStep = lastChange.stepTime + Math.floor(decimalStep);
	}

	/**
	 * Executes the `stepHit` operation.
	 */
	public function stepHit():Void
	{
		if (curStep % 4 == 0)
			beatHit();
	}

	/**
	 * Executes the `beatHit` operation.
	 */
	public function beatHit():Void
	{
		//do literally nothing dumbass
	}
}
