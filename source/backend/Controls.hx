package backend;

import flixel.input.FlxInput;
import flixel.input.actions.FlxAction;
import flixel.input.actions.FlxActionInput;
import flixel.input.actions.FlxActionInputDigital;
import flixel.input.actions.FlxActionManager;
import flixel.input.actions.FlxActionSet;
import flixel.input.gamepad.FlxGamepadInputID;
import flixel.input.keyboard.FlxKey;
import mobile.flixel.FlxButton;
import mobile.flixel.FlxHitbox;
import mobile.flixel.FlxVirtualPad;

enum abstract Action(String) to String from String
{
	var UI_UP = "ui_up";
	var UI_LEFT = "ui_left";
	var UI_RIGHT = "ui_right";
	var UI_DOWN = "ui_down";
	var UI_UP_P = "ui_up-press";
	var UI_LEFT_P = "ui_left-press";
	var UI_RIGHT_P = "ui_right-press";
	var UI_DOWN_P = "ui_down-press";
	var UI_UP_R = "ui_up-release";
	var UI_LEFT_R = "ui_left-release";
	var UI_RIGHT_R = "ui_right-release";
	var UI_DOWN_R = "ui_down-release";
	var NOTE_UP = "note_up";
	var NOTE_LEFT = "note_left";
	var NOTE_RIGHT = "note_right";
	var NOTE_DOWN = "note_down";
	var NOTE_UP_P = "note_up-press";
	var NOTE_LEFT_P = "note_left-press";
	var NOTE_RIGHT_P = "note_right-press";
	var NOTE_DOWN_P = "note_down-press";
	var NOTE_UP_R = "note_up-release";
	var NOTE_LEFT_R = "note_left-release";
	var NOTE_RIGHT_R = "note_right-release";
	var NOTE_DOWN_R = "note_down-release";
	var BOT_ENERGY_P = "bot_energy-press";
	var ACCEPT = "accept";
	var ACCEPT_P = "accept-press";
	var BACK = "back";
	var PAUSE = "pause";
	var RESET = "reset";
}

enum Device
{
	Keys;
	Gamepad(id:Int);
}

/**
 * Since, in many cases multiple actions should use similar keys, we don't want the
 * rebinding UI to list every action. ActionBinders are what the user percieves as
 * an input so, for instance, they can't set jump-press and jump-release to different keys.
 */
enum Control
{
	UI_UP;
	UI_LEFT;
	UI_RIGHT;
	UI_DOWN;
	NOTE_UP;
	NOTE_LEFT;
	NOTE_RIGHT;
	NOTE_DOWN;
	RESET;
	BOT_ENERGY;
	ACCEPT;
	BACK;
	PAUSE;
}

enum KeyboardScheme
{
	Solo;
	Duo(first:Bool);
	None;
	Custom;
}

/**
 * A list of actions that a player would invoke via some input device.
 * Uses FlxActions to funnel various inputs to a single action.
 */
class Controls extends FlxActionSet
{
	var _ui_up = new FlxActionDigital(Action.UI_UP);
	var _ui_left = new FlxActionDigital(Action.UI_LEFT);
	var _ui_right = new FlxActionDigital(Action.UI_RIGHT);
	var _ui_down = new FlxActionDigital(Action.UI_DOWN);
	var _ui_upP = new FlxActionDigital(Action.UI_UP_P);
	var _ui_leftP = new FlxActionDigital(Action.UI_LEFT_P);
	var _ui_rightP = new FlxActionDigital(Action.UI_RIGHT_P);
	var _ui_downP = new FlxActionDigital(Action.UI_DOWN_P);
	var _ui_upR = new FlxActionDigital(Action.UI_UP_R);
	var _ui_leftR = new FlxActionDigital(Action.UI_LEFT_R);
	var _ui_rightR = new FlxActionDigital(Action.UI_RIGHT_R);
	var _ui_downR = new FlxActionDigital(Action.UI_DOWN_R);
	var _note_up = new FlxActionDigital(Action.NOTE_UP);
	var _note_left = new FlxActionDigital(Action.NOTE_LEFT);
	var _note_right = new FlxActionDigital(Action.NOTE_RIGHT);
	var _note_down = new FlxActionDigital(Action.NOTE_DOWN);
	var _note_upP = new FlxActionDigital(Action.NOTE_UP_P);
	var _note_leftP = new FlxActionDigital(Action.NOTE_LEFT_P);
	var _note_rightP = new FlxActionDigital(Action.NOTE_RIGHT_P);
	var _note_downP = new FlxActionDigital(Action.NOTE_DOWN_P);
	var _note_upR = new FlxActionDigital(Action.NOTE_UP_R);
	var _note_leftR = new FlxActionDigital(Action.NOTE_LEFT_R);
	var _note_rightR = new FlxActionDigital(Action.NOTE_RIGHT_R);
	var _note_downR = new FlxActionDigital(Action.NOTE_DOWN_R);
	var _bot_energyP = new FlxActionDigital(Action.BOT_ENERGY_P);
	var _accept = new FlxActionDigital(Action.ACCEPT);
	var _acceptP = new FlxActionDigital(Action.ACCEPT_P);
	var _back = new FlxActionDigital(Action.BACK);
	var _pause = new FlxActionDigital(Action.PAUSE);
	var _reset = new FlxActionDigital(Action.RESET);

	var byName:Map<String, FlxActionDigital> = [];

	public var gamepadsAdded:Array<Int> = [];
	public var keyboardScheme = KeyboardScheme.None;

	public var UI_UP(get, never):Bool;

	/**
	 * Executes the `get_UI_UP` operation.
	 * @return Result produced by `get_UI_UP`, when applicable.
	 */
	inline function get_UI_UP()
		return _ui_up.check();

	public var UI_LEFT(get, never):Bool;

	/**
	 * Executes the `get_UI_LEFT` operation.
	 * @return Result produced by `get_UI_LEFT`, when applicable.
	 */
	inline function get_UI_LEFT()
		return _ui_left.check();

	public var UI_RIGHT(get, never):Bool;

	/**
	 * Executes the `get_UI_RIGHT` operation.
	 * @return Result produced by `get_UI_RIGHT`, when applicable.
	 */
	inline function get_UI_RIGHT()
		return _ui_right.check();

	public var UI_DOWN(get, never):Bool;

	/**
	 * Executes the `get_UI_DOWN` operation.
	 * @return Result produced by `get_UI_DOWN`, when applicable.
	 */
	inline function get_UI_DOWN()
		return _ui_down.check();

	public var UI_UP_P(get, never):Bool;

	/**
	 * Executes the `get_UI_UP_P` operation.
	 * @return Result produced by `get_UI_UP_P`, when applicable.
	 */
	inline function get_UI_UP_P()
		return _ui_upP.check();

	public var UI_LEFT_P(get, never):Bool;

	/**
	 * Executes the `get_UI_LEFT_P` operation.
	 * @return Result produced by `get_UI_LEFT_P`, when applicable.
	 */
	inline function get_UI_LEFT_P()
		return _ui_leftP.check();

	public var UI_RIGHT_P(get, never):Bool;

	/**
	 * Executes the `get_UI_RIGHT_P` operation.
	 * @return Result produced by `get_UI_RIGHT_P`, when applicable.
	 */
	inline function get_UI_RIGHT_P()
		return _ui_rightP.check();

	public var UI_DOWN_P(get, never):Bool;

	/**
	 * Executes the `get_UI_DOWN_P` operation.
	 * @return Result produced by `get_UI_DOWN_P`, when applicable.
	 */
	inline function get_UI_DOWN_P()
		return _ui_downP.check();

	public var UI_UP_R(get, never):Bool;

	/**
	 * Executes the `get_UI_UP_R` operation.
	 * @return Result produced by `get_UI_UP_R`, when applicable.
	 */
	inline function get_UI_UP_R()
		return _ui_upR.check();

	public var UI_LEFT_R(get, never):Bool;

	/**
	 * Executes the `get_UI_LEFT_R` operation.
	 * @return Result produced by `get_UI_LEFT_R`, when applicable.
	 */
	inline function get_UI_LEFT_R()
		return _ui_leftR.check();

	public var UI_RIGHT_R(get, never):Bool;

	/**
	 * Executes the `get_UI_RIGHT_R` operation.
	 * @return Result produced by `get_UI_RIGHT_R`, when applicable.
	 */
	inline function get_UI_RIGHT_R()
		return _ui_rightR.check();

	public var UI_DOWN_R(get, never):Bool;

	/**
	 * Executes the `get_UI_DOWN_R` operation.
	 * @return Result produced by `get_UI_DOWN_R`, when applicable.
	 */
	inline function get_UI_DOWN_R()
		return _ui_downR.check();

	public var NOTE_UP(get, never):Bool;

	/**
	 * Executes the `get_NOTE_UP` operation.
	 * @return Result produced by `get_NOTE_UP`, when applicable.
	 */
	inline function get_NOTE_UP()
		return _note_up.check();

	public var NOTE_LEFT(get, never):Bool;

	/**
	 * Executes the `get_NOTE_LEFT` operation.
	 * @return Result produced by `get_NOTE_LEFT`, when applicable.
	 */
	inline function get_NOTE_LEFT()
		return _note_left.check();

	public var NOTE_RIGHT(get, never):Bool;

	/**
	 * Executes the `get_NOTE_RIGHT` operation.
	 * @return Result produced by `get_NOTE_RIGHT`, when applicable.
	 */
	inline function get_NOTE_RIGHT()
		return _note_right.check();

	public var NOTE_DOWN(get, never):Bool;

	/**
	 * Executes the `get_NOTE_DOWN` operation.
	 * @return Result produced by `get_NOTE_DOWN`, when applicable.
	 */
	inline function get_NOTE_DOWN()
		return _note_down.check();

	public var NOTE_UP_P(get, never):Bool;

	/**
	 * Executes the `get_NOTE_UP_P` operation.
	 * @return Result produced by `get_NOTE_UP_P`, when applicable.
	 */
	inline function get_NOTE_UP_P()
		return _note_upP.check();

	public var NOTE_LEFT_P(get, never):Bool;

	/**
	 * Executes the `get_NOTE_LEFT_P` operation.
	 * @return Result produced by `get_NOTE_LEFT_P`, when applicable.
	 */
	inline function get_NOTE_LEFT_P()
		return _note_leftP.check();

	public var NOTE_RIGHT_P(get, never):Bool;

	/**
	 * Executes the `get_NOTE_RIGHT_P` operation.
	 * @return Result produced by `get_NOTE_RIGHT_P`, when applicable.
	 */
	inline function get_NOTE_RIGHT_P()
		return _note_rightP.check();

	public var NOTE_DOWN_P(get, never):Bool;

	/**
	 * Executes the `get_NOTE_DOWN_P` operation.
	 * @return Result produced by `get_NOTE_DOWN_P`, when applicable.
	 */
	inline function get_NOTE_DOWN_P()
		return _note_downP.check();

	public var NOTE_UP_R(get, never):Bool;

	/**
	 * Executes the `get_NOTE_UP_R` operation.
	 * @return Result produced by `get_NOTE_UP_R`, when applicable.
	 */
	inline function get_NOTE_UP_R()
		return _note_upR.check();

	public var NOTE_LEFT_R(get, never):Bool;

	/**
	 * Executes the `get_NOTE_LEFT_R` operation.
	 * @return Result produced by `get_NOTE_LEFT_R`, when applicable.
	 */
	inline function get_NOTE_LEFT_R()
		return _note_leftR.check();

	public var NOTE_RIGHT_R(get, never):Bool;

	/**
	 * Executes the `get_NOTE_RIGHT_R` operation.
	 * @return Result produced by `get_NOTE_RIGHT_R`, when applicable.
	 */
	inline function get_NOTE_RIGHT_R()
		return _note_rightR.check();

	public var NOTE_DOWN_R(get, never):Bool;

	/**
	 * Executes the `get_NOTE_DOWN_R` operation.
	 * @return Result produced by `get_NOTE_DOWN_R`, when applicable.
	 */
	inline function get_NOTE_DOWN_R()
		return _note_downR.check();

	public var BOT_ENERGY_P(get, never):Bool;

	/**
	 * Executes the `get_BOT_ENERGY_P` operation.
	 * @return Result produced by `get_BOT_ENERGY_P`, when applicable.
	 */
	inline function get_BOT_ENERGY_P()
		return _bot_energyP.check();

	public var ACCEPT(get, never):Bool;

	/**
	 * Executes the `get_ACCEPT` operation.
	 * @return Result produced by `get_ACCEPT`, when applicable.
	 */
	inline function get_ACCEPT()
		return _accept.check();

	public var ACCEPT_P(get, never):Bool;

	/**
	 * Executes the `get_ACCEPT_P` operation.
	 * @return Result produced by `get_ACCEPT_P`, when applicable.
	 */
	inline function get_ACCEPT_P()
		return _acceptP.check();

	public var BACK(get, never):Bool;

	/**
	 * Executes the `get_BACK` operation.
	 * @return Result produced by `get_BACK`, when applicable.
	 */
	inline function get_BACK()
		return _back.check();

	public var PAUSE(get, never):Bool;

	/**
	 * Executes the `get_PAUSE` operation.
	 * @return Result produced by `get_PAUSE`, when applicable.
	 */
	inline function get_PAUSE()
		return _pause.check();

	public var RESET(get, never):Bool;

	/**
	 * Executes the `get_RESET` operation.
	 * @return Result produced by `get_RESET`, when applicable.
	 */
	inline function get_RESET()
		return _reset.check();

	public static var instance:Controls;

	/**
	 * Executes the `new` operation.
	 * @param name Input value for `name`.
	 * @param scheme Input value for `scheme`.
	 */
	public function new(name, scheme = None)
	{
		super(name);

		add(_ui_up);
		add(_ui_left);
		add(_ui_right);
		add(_ui_down);
		add(_ui_upP);
		add(_ui_leftP);
		add(_ui_rightP);
		add(_ui_downP);
		add(_ui_upR);
		add(_ui_leftR);
		add(_ui_rightR);
		add(_ui_downR);
		add(_note_up);
		add(_note_left);
		add(_note_right);
		add(_note_down);
		add(_note_upP);
		add(_note_leftP);
		add(_note_rightP);
		add(_note_downP);
		add(_note_upR);
		add(_note_leftR);
		add(_note_rightR);
		add(_note_downR);
		add(_bot_energyP);
		add(_accept);
		add(_acceptP);
		add(_back);
		add(_pause);
		add(_reset);

		for (action in digitalActions)
			byName[action.name] = action;

		setKeyboardScheme(scheme, false);

		instance = this;
	}

	public var trackedInputsUI:Array<FlxActionInput> = [];
	public var trackedInputsNOTES:Array<FlxActionInput> = [];

	/**
	 * Executes the `addButtonNOTES` operation.
	 * @param action Input value for `action`.
	 * @param button Input value for `button`.
	 * @param state Input value for `state`.
	 */
	public function addButtonNOTES(action:FlxActionDigital, button:FlxButton, state:FlxInputState):Void
	{
		if (button == null)
			return;

		var input:FlxActionInputDigitalIFlxInput = new FlxActionInputDigitalIFlxInput(button, state);
		trackedInputsNOTES.push(input);
		action.add(input);
	}

	/**
	 * Executes the `addButtonUI` operation.
	 * @param action Input value for `action`.
	 * @param button Input value for `button`.
	 * @param state Input value for `state`.
	 */
	public function addButtonUI(action:FlxActionDigital, button:FlxButton, state:FlxInputState):Void
	{
		if (button == null)
			return;

		var input:FlxActionInputDigitalIFlxInput = new FlxActionInputDigitalIFlxInput(button, state);
		trackedInputsUI.push(input);
		action.add(input);
	}

	/**
	 * Executes the `setHitBox` operation.
	 * @param Hitbox Input value for `Hitbox`.
	 */
	public function setHitBox(Hitbox:FlxHitbox):Void
	{
		if (Hitbox == null)
			return;

		inline forEachBound(Control.NOTE_LEFT, (action, state) -> addButtonNOTES(action, Hitbox.hints[0], state));
		inline forEachBound(Control.NOTE_DOWN, (action, state) -> addButtonNOTES(action, Hitbox.hints[1], state));
		inline forEachBound(Control.NOTE_UP, (action, state) -> addButtonNOTES(action, Hitbox.hints[2], state));
		inline forEachBound(Control.NOTE_RIGHT, (action, state) -> addButtonNOTES(action, Hitbox.hints[3], state));
	}

	/**
	 * Executes the `setVirtualPadUI` operation.
	 * @param VirtualPad Input value for `VirtualPad`.
	 * @param DPad Input value for `DPad`.
	 * @param Action Input value for `Action`.
	 */
	public function setVirtualPadUI(VirtualPad:FlxVirtualPad, DPad:FlxDPadMode, Action:FlxActionMode):Void
	{
		if (VirtualPad == null)
			return;

		switch (DPad)
		{
			case UP_DOWN:
				inline forEachBound(Control.UI_UP, (action, state) -> addButtonUI(action, VirtualPad.buttonUp, state));
				inline forEachBound(Control.UI_DOWN, (action, state) -> addButtonUI(action, VirtualPad.buttonDown, state));
			case LEFT_RIGHT:
				inline forEachBound(Control.UI_LEFT, (action, state) -> addButtonUI(action, VirtualPad.buttonLeft, state));
				inline forEachBound(Control.UI_RIGHT, (action, state) -> addButtonUI(action, VirtualPad.buttonRight, state));
			case BOTH_FULL | DIALOGUE_PORTRAIT_EDITOR:
				inline forEachBound(Control.UI_UP, (action, state) -> addButtonUI(action, VirtualPad.buttonUp, state));
				inline forEachBound(Control.UI_DOWN, (action, state) -> addButtonUI(action, VirtualPad.buttonDown, state));
				inline forEachBound(Control.UI_LEFT, (action, state) -> addButtonUI(action, VirtualPad.buttonLeft, state));
				inline forEachBound(Control.UI_RIGHT, (action, state) -> addButtonUI(action, VirtualPad.buttonRight, state));
				inline forEachBound(Control.UI_UP, (action, state) -> addButtonUI(action, VirtualPad.buttonUp2, state));
				inline forEachBound(Control.UI_DOWN, (action, state) -> addButtonUI(action, VirtualPad.buttonDown2, state));
				inline forEachBound(Control.UI_LEFT, (action, state) -> addButtonUI(action, VirtualPad.buttonLeft2, state));
				inline forEachBound(Control.UI_RIGHT, (action, state) -> addButtonUI(action, VirtualPad.buttonRight2, state));
			default:
				inline forEachBound(Control.UI_UP, (action, state) -> addButtonUI(action, VirtualPad.buttonUp, state));
				inline forEachBound(Control.UI_DOWN, (action, state) -> addButtonUI(action, VirtualPad.buttonDown, state));
				inline forEachBound(Control.UI_LEFT, (action, state) -> addButtonUI(action, VirtualPad.buttonLeft, state));
				inline forEachBound(Control.UI_RIGHT, (action, state) -> addButtonUI(action, VirtualPad.buttonRight, state));
			case NONE: // do nothing
		}

		switch (Action)
		{
			case A:
				inline forEachBound(Control.ACCEPT, (action, state) -> addButtonUI(action, VirtualPad.buttonA, state));
			case B:
				inline forEachBound(Control.BACK, (action, state) -> addButtonUI(action, VirtualPad.buttonB, state));
			case P:
				inline forEachBound(Control.PAUSE, (action, state) -> addButtonUI(action, VirtualPad.buttonP, state));
			case NONE: // do nothing
			default:
				inline forEachBound(Control.ACCEPT, (action, state) -> addButtonUI(action, VirtualPad.buttonA, state));
				inline forEachBound(Control.BACK, (action, state) -> addButtonUI(action, VirtualPad.buttonB, state));
		}
	}

	/**
	 * Executes the `setVirtualPadNOTES` operation.
	 * @param VirtualPad Input value for `VirtualPad`.
	 * @param DPad Input value for `DPad`.
	 * @param Action Input value for `Action`.
	 */
	public function setVirtualPadNOTES(VirtualPad:FlxVirtualPad, DPad:FlxDPadMode, Action:FlxActionMode):Void
	{
		if (VirtualPad == null)
			return;

		switch (DPad)
		{
			case UP_DOWN:
				inline forEachBound(Control.NOTE_UP, (action, state) -> addButtonNOTES(action, VirtualPad.buttonUp, state));
				inline forEachBound(Control.NOTE_DOWN, (action, state) -> addButtonNOTES(action, VirtualPad.buttonDown, state));
			case LEFT_RIGHT:
				inline forEachBound(Control.NOTE_LEFT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonLeft, state));
				inline forEachBound(Control.NOTE_RIGHT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonRight, state));
			case BOTH_FULL | DIALOGUE_PORTRAIT_EDITOR:
				inline forEachBound(Control.NOTE_UP, (action, state) -> addButtonNOTES(action, VirtualPad.buttonUp, state));
				inline forEachBound(Control.NOTE_DOWN, (action, state) -> addButtonNOTES(action, VirtualPad.buttonDown, state));
				inline forEachBound(Control.NOTE_LEFT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonLeft, state));
				inline forEachBound(Control.NOTE_RIGHT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonRight, state));
				inline forEachBound(Control.NOTE_UP, (action, state) -> addButtonNOTES(action, VirtualPad.buttonUp2, state));
				inline forEachBound(Control.NOTE_DOWN, (action, state) -> addButtonNOTES(action, VirtualPad.buttonDown2, state));
				inline forEachBound(Control.NOTE_LEFT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonLeft2, state));
				inline forEachBound(Control.NOTE_RIGHT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonRight2, state));
			default:
				inline forEachBound(Control.NOTE_UP, (action, state) -> addButtonNOTES(action, VirtualPad.buttonUp, state));
				inline forEachBound(Control.NOTE_DOWN, (action, state) -> addButtonNOTES(action, VirtualPad.buttonDown, state));
				inline forEachBound(Control.NOTE_LEFT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonLeft, state));
				inline forEachBound(Control.NOTE_RIGHT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonRight, state));
			case NONE: // do nothing
		}

		switch (Action)
		{
			case A:
				inline forEachBound(Control.ACCEPT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonA, state));
			case B:
				inline forEachBound(Control.BACK, (action, state) -> addButtonNOTES(action, VirtualPad.buttonB, state));
			case P:
				inline forEachBound(Control.PAUSE, (action, state) -> addButtonNOTES(action, VirtualPad.buttonP, state));
			case NONE: // do nothing
			default:
			inline forEachBound(Control.ACCEPT, (action, state) -> addButtonNOTES(action, VirtualPad.buttonA, state));
			inline forEachBound(Control.BACK, (action, state) -> addButtonNOTES(action, VirtualPad.buttonB, state));
		}
	}

	/**
	 * Executes the `removeVirtualControlsInput` operation.
	 * @param Tinputs Input value for `Tinputs`.
	 */
	public function removeVirtualControlsInput(Tinputs:Array<FlxActionInput>):Void
	{
		for (action in this.digitalActions)
		{
			var i = action.inputs.length;
			while (i-- > 0)
			{
				var x = Tinputs.length;
				while (x-- > 0)
				{
					if (Tinputs[x] == action.inputs[i])
						action.remove(action.inputs[i]);
				}
			}
		}
	}

	/**
	 * Executes the `update` operation.
	 * @return Result produced by `update`, when applicable.
	 */
	override function update()
	{
		super.update();
	}

	// inline
	/**
	 * Executes the `checkByName` operation.
	 * @param name Input value for `name`.
	 * @return Result produced by `checkByName`, when applicable.
	 */
	public function checkByName(name:Action):Bool
	{
		#if debug
		if (!byName.exists(name))
			throw 'Invalid name: $name';
		#end
		return byName[name].check();
	}

	/**
	 * Executes the `getDialogueName` operation.
	 * @param action Input value for `action`.
	 * @return Result produced by `getDialogueName`, when applicable.
	 */
	public function getDialogueName(action:FlxActionDigital):String
	{
		var input = action.inputs[0];
		return switch input.device
		{
			case KEYBOARD: return '[${(input.inputID : FlxKey)}]';
			case GAMEPAD: return '(${(input.inputID : FlxGamepadInputID)})';
			case device: throw 'unhandled device: $device';
		}
	}

	/**
	 * Executes the `getDialogueNameFromToken` operation.
	 * @param token Input value for `token`.
	 * @return Result produced by `getDialogueNameFromToken`, when applicable.
	 */
	public function getDialogueNameFromToken(token:String):String
	{
		return getDialogueName(getActionFromControl(Control.createByName(token.toUpperCase())));
	}

	/**
	 * Executes the `getActionFromControl` operation.
	 * @param control Input value for `control`.
	 * @return Result produced by `getActionFromControl`, when applicable.
	 */
	function getActionFromControl(control:Control):FlxActionDigital
	{
		return switch (control)
		{
			case UI_UP: _ui_up;
			case UI_DOWN: _ui_down;
			case UI_LEFT: _ui_left;
			case UI_RIGHT: _ui_right;
			case NOTE_UP: _note_up;
			case NOTE_DOWN: _note_down;
			case NOTE_LEFT: _note_left;
			case NOTE_RIGHT: _note_right;
			case BOT_ENERGY: _bot_energyP;
			case ACCEPT: _accept;
			case BACK: _back;
			case PAUSE: _pause;
			case RESET: _reset;
		}
	}

	/**
	 * Executes the `init` operation.
	 */
	static function init():Void
	{
		var actions = new FlxActionManager();
		FlxG.inputs.add(actions);
	}

	/**
	 * Calls a function passing each action bound by the specified control
	 * @param control
	 * @param func
	 * @return ->Void)
	 */
	function forEachBound(control:Control, func:FlxActionDigital->FlxInputState->Void)
	{
		switch (control)
		{
			case UI_UP:
				func(_ui_up, PRESSED);
				func(_ui_upP, JUST_PRESSED);
				func(_ui_upR, JUST_RELEASED);
			case UI_LEFT:
				func(_ui_left, PRESSED);
				func(_ui_leftP, JUST_PRESSED);
				func(_ui_leftR, JUST_RELEASED);
			case UI_RIGHT:
				func(_ui_right, PRESSED);
				func(_ui_rightP, JUST_PRESSED);
				func(_ui_rightR, JUST_RELEASED);
			case UI_DOWN:
				func(_ui_down, PRESSED);
				func(_ui_downP, JUST_PRESSED);
				func(_ui_downR, JUST_RELEASED);
			case NOTE_UP:
				func(_note_up, PRESSED);
				func(_note_upP, JUST_PRESSED);
				func(_note_upR, JUST_RELEASED);
			case NOTE_LEFT:
				func(_note_left, PRESSED);
				func(_note_leftP, JUST_PRESSED);
				func(_note_leftR, JUST_RELEASED);
			case NOTE_RIGHT:
				func(_note_right, PRESSED);
				func(_note_rightP, JUST_PRESSED);
				func(_note_rightR, JUST_RELEASED);
			case NOTE_DOWN:
				func(_note_down, PRESSED);
				func(_note_downP, JUST_PRESSED);
				func(_note_downR, JUST_RELEASED);
			case BOT_ENERGY:
				func(_bot_energyP, PRESSED);
			case ACCEPT:
				func(_accept, JUST_PRESSED);
				func(_acceptP, PRESSED);
			case BACK:
				func(_back, JUST_PRESSED);
			case PAUSE:
				func(_pause, JUST_PRESSED);
			case RESET:
				func(_reset, JUST_PRESSED);
		}
	}

	/**
	 * Executes the `replaceBinding` operation.
	 * @param control Input value for `control`.
	 * @param device Input value for `device`.
	 * @param toAdd Input value for `toAdd`.
	 * @param toRemove Input value for `toRemove`.
	 * @return Result produced by `replaceBinding`, when applicable.
	 */
	public function replaceBinding(control:Control, device:Device, ?toAdd:Int, ?toRemove:Int)
	{
		if (toAdd == toRemove)
			return;

		switch (device)
		{
			case Keys:
				if (toRemove != null)
					unbindKeys(control, [toRemove]);
				if (toAdd != null)
					bindKeys(control, [toAdd]);

			case Gamepad(id):
				if (toRemove != null)
					unbindButtons(control, id, [toRemove]);
				if (toAdd != null)
					bindButtons(control, id, [toAdd]);
		}
	}

	/**
	 * Executes the `copyFrom` operation.
	 * @param controls Input value for `controls`.
	 * @param device Input value for `device`.
	 * @return Result produced by `copyFrom`, when applicable.
	 */
	public function copyFrom(controls:Controls, ?device:Device)
	{
		for (name => action in controls.byName)
		{
			for (input in action.inputs)
			{
				if (device == null || isDevice(input, device))
					byName[name].add(cast input);
			}
		}

		switch (device)
		{
			case null:
				// add all
				for (gamepad in controls.gamepadsAdded)
					if (!gamepadsAdded.contains(gamepad))
						gamepadsAdded.push(gamepad);

				mergeKeyboardScheme(controls.keyboardScheme);

			case Gamepad(id):
				gamepadsAdded.push(id);
			case Keys:
				mergeKeyboardScheme(controls.keyboardScheme);
		}
	}

	/**
	 * Executes the `copyTo` operation.
	 * @param controls Input value for `controls`.
	 * @param device Input value for `device`.
	 * @return Result produced by `copyTo`, when applicable.
	 */
	inline public function copyTo(controls:Controls, ?device:Device)
	{
		controls.copyFrom(this, device);
	}

	/**
	 * Executes the `mergeKeyboardScheme` operation.
	 * @param scheme Input value for `scheme`.
	 */
	function mergeKeyboardScheme(scheme:KeyboardScheme):Void
	{
		if (scheme != None)
		{
			switch (keyboardScheme)
			{
				case None:
					keyboardScheme = scheme;
				default:
					keyboardScheme = Custom;
			}
		}
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
	 */
	public function bindKeys(control:Control, keys:Array<FlxKey>) {
		var copyKeys:Array<FlxKey> = keys.copy();
		for (i in 0...copyKeys.length) {
			if (copyKeys[i] == FlxKey.NONE)
				copyKeys.remove(FlxKey.NONE);
		}

		inline forEachBound(control, (action, state) -> addKeys(action, copyKeys, state));
	}

	/**
	 * Executes the `unbindKeys` operation.
	 * @param control Input value for `control`.
	 * @param keys Input value for `keys`.
	 * @return Result produced by `unbindKeys`, when applicable.
	 */
	public function unbindKeys(control:Control, keys:Array<FlxKey>) {
		var copyKeys:Array<FlxKey> = keys.copy();
		for (i in 0...copyKeys.length) {
			if (copyKeys[i] == FlxKey.NONE)
				copyKeys.remove(FlxKey.NONE);
		}

		inline forEachBound(control, (action, _) -> removeKeys(action, copyKeys));
	}

	/**
	 * Executes the `addKeys` operation.
	 * @param action Input value for `action`.
	 * @param keys Input value for `keys`.
	 * @param state Input value for `state`.
	 * @return Result produced by `addKeys`, when applicable.
	 */
	inline static function addKeys(action:FlxActionDigital, keys:Array<FlxKey>, state:FlxInputState)
	{
		for (key in keys)
			if(key != NONE)
				action.addKey(key, state);
	}

	/**
	 * Executes the `removeKeys` operation.
	 * @param action Input value for `action`.
	 * @param keys Input value for `keys`.
	 * @return Result produced by `removeKeys`, when applicable.
	 */
	static function removeKeys(action:FlxActionDigital, keys:Array<FlxKey>)
	{
		var i = action.inputs.length;
		while (i-- > 0)
		{
			var input = action.inputs[i];
			if (input.device == KEYBOARD && keys.indexOf(cast input.inputID) != -1)
				action.remove(input);
		}
	}

	/**
	 * Executes the `setKeyboardScheme` operation.
	 * @param scheme Input value for `scheme`.
	 * @param reset Input value for `reset`.
	 * @return Result produced by `setKeyboardScheme`, when applicable.
	 */
	public function setKeyboardScheme(scheme:KeyboardScheme, reset = true)
	{
		if (reset)
			removeKeyboard();

		keyboardScheme = scheme;
		var keysMap = ClientPrefs.keyBinds;

		switch (scheme)
		{
			case Solo:
				inline bindKeys(Control.UI_UP, keysMap.get('ui_up'));
				inline bindKeys(Control.UI_DOWN, keysMap.get('ui_down'));
				inline bindKeys(Control.UI_LEFT, keysMap.get('ui_left'));
				inline bindKeys(Control.UI_RIGHT, keysMap.get('ui_right'));
				inline bindKeys(Control.NOTE_UP, keysMap.get('note_up'));
				inline bindKeys(Control.NOTE_DOWN, keysMap.get('note_down'));
				inline bindKeys(Control.NOTE_LEFT, keysMap.get('note_left'));
				inline bindKeys(Control.NOTE_RIGHT, keysMap.get('note_right'));

				inline bindKeys(Control.BOT_ENERGY, keysMap.get('bot_energy'));
				inline bindKeys(Control.ACCEPT, keysMap.get('accept'));
				inline bindKeys(Control.BACK, keysMap.get('back'));
				inline bindKeys(Control.PAUSE, keysMap.get('pause'));
				inline bindKeys(Control.RESET, keysMap.get('reset'));
			case Duo(true):
				inline bindKeys(Control.UI_UP, [W]);
				inline bindKeys(Control.UI_DOWN, [S]);
				inline bindKeys(Control.UI_LEFT, [A]);
				inline bindKeys(Control.UI_RIGHT, [D]);
				inline bindKeys(Control.NOTE_UP, [W]);
				inline bindKeys(Control.NOTE_DOWN, [S]);
				inline bindKeys(Control.NOTE_LEFT, [A]);
				inline bindKeys(Control.NOTE_RIGHT, [D]);
				inline bindKeys(Control.BOT_ENERGY, [FlxKey.CONTROL]);
				inline bindKeys(Control.ACCEPT, [G, Z]);
				inline bindKeys(Control.BACK, [H, X]);
				inline bindKeys(Control.PAUSE, [ONE]);
				inline bindKeys(Control.RESET, [R]);
			case Duo(false):
				inline bindKeys(Control.UI_UP, [FlxKey.UP]);
				inline bindKeys(Control.UI_DOWN, [FlxKey.DOWN]);
				inline bindKeys(Control.UI_LEFT, [FlxKey.LEFT]);
				inline bindKeys(Control.UI_RIGHT, [FlxKey.RIGHT]);
				inline bindKeys(Control.NOTE_UP, [FlxKey.UP]);
				inline bindKeys(Control.NOTE_DOWN, [FlxKey.DOWN]);
				inline bindKeys(Control.NOTE_LEFT, [FlxKey.LEFT]);
				inline bindKeys(Control.NOTE_RIGHT, [FlxKey.RIGHT]);
				inline bindKeys(Control.BOT_ENERGY, [CONTROL]);
				inline bindKeys(Control.ACCEPT, [O]);
				inline bindKeys(Control.BACK, [P]);
				inline bindKeys(Control.PAUSE, [ENTER]);
				inline bindKeys(Control.RESET, [BACKSPACE]);
			case None: // nothing
			case Custom: // nothing
		}
	}

	/**
	 * Executes the `removeKeyboard` operation.
	 * @return Result produced by `removeKeyboard`, when applicable.
	 */
	function removeKeyboard()
	{
		for (action in this.digitalActions)
		{
			var i = action.inputs.length;
			while (i-- > 0)
			{
				var input = action.inputs[i];
				if (input.device == KEYBOARD)
					action.remove(input);
			}
		}
	}

	/**
	 * Executes the `addGamepad` operation.
	 * @param id Input value for `id`.
	 * @param buttonMap Input value for `buttonMap`.
	 */
	public function addGamepad(id:Int, ?buttonMap:Map<Control, Array<FlxGamepadInputID>>):Void
	{
		gamepadsAdded.push(id);

		for (control => buttons in buttonMap)
			inline bindButtons(control, id, buttons);
	}

	/**
	 * Executes the `addGamepadLiteral` operation.
	 * @param id Input value for `id`.
	 * @param buttonMap Input value for `buttonMap`.
	 */
	inline function addGamepadLiteral(id:Int, ?buttonMap:Map<Control, Array<FlxGamepadInputID>>):Void
	{
		gamepadsAdded.push(id);

		for (control => buttons in buttonMap)
			inline bindButtons(control, id, buttons);
	}

	/**
	 * Executes the `removeGamepad` operation.
	 * @param deviceID Input value for `deviceID`.
	 */
	public function removeGamepad(deviceID:Int = FlxInputDeviceID.ALL):Void
	{
		for (action in this.digitalActions)
		{
			var i = action.inputs.length;
			while (i-- > 0)
			{
				var input = action.inputs[i];
				if (input.device == GAMEPAD && (deviceID == FlxInputDeviceID.ALL || input.deviceID == deviceID))
					action.remove(input);
			}
		}

		gamepadsAdded.remove(deviceID);
	}

	/**
	 * Executes the `addDefaultGamepad` operation.
	 * @param id Input value for `id`.
	 */
	public function addDefaultGamepad(id):Void
	{
		#if !switch
		addGamepadLiteral(id, [
			Control.ACCEPT => [A, START],
			Control.BACK => [B],
			Control.UI_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP],
			Control.UI_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN],
			Control.UI_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT],
			Control.UI_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT],
			Control.NOTE_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP, Y],
			Control.NOTE_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN, A],
			Control.NOTE_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT, X],
			Control.NOTE_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT, B],
			Control.PAUSE => [START],
			Control.RESET => [8]
		]);
		#else
		addGamepadLiteral(id, [
			//Swap A and B for switch
			Control.ACCEPT => [B, START],
			Control.BACK => [A],
			Control.UI_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP],
			Control.UI_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN],
			Control.UI_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT],
			Control.UI_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT],
			Control.NOTE_UP => [DPAD_UP, LEFT_STICK_DIGITAL_UP, RIGHT_STICK_DIGITAL_UP, X],
			Control.NOTE_DOWN => [DPAD_DOWN, LEFT_STICK_DIGITAL_DOWN, RIGHT_STICK_DIGITAL_DOWN, B],
			Control.NOTE_LEFT => [DPAD_LEFT, LEFT_STICK_DIGITAL_LEFT, RIGHT_STICK_DIGITAL_LEFT, Y],
			Control.NOTE_RIGHT => [DPAD_RIGHT, LEFT_STICK_DIGITAL_RIGHT, RIGHT_STICK_DIGITAL_RIGHT, A],
			Control.PAUSE => [START],
			Control.RESET => [8],
		]);
		#end
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
*/
	public function bindButtons(control:Control, id, buttons)
	{
		inline forEachBound(control, (action, state) -> addButtons(action, buttons, state, id));
	}

	/**
	 * Sets all actions that pertain to the binder to trigger when the supplied keys are used.
	 * If binder is a literal you can inline this
*/
	public function unbindButtons(control:Control, gamepadID:Int, buttons)
	{
		inline forEachBound(control, (action, _) -> removeButtons(action, gamepadID, buttons));
	}

	/**
	 * Executes the `addButtons` operation.
	 * @param action Input value for `action`.
	 * @param buttons Input value for `buttons`.
	 * @param state Input value for `state`.
	 * @param id Input value for `id`.
	 * @return Result produced by `addButtons`, when applicable.
	 */
	inline static function addButtons(action:FlxActionDigital, buttons:Array<FlxGamepadInputID>, state, id)
	{
		for (button in buttons)
			action.addGamepad(button, state, id);
	}

	/**
	 * Executes the `removeButtons` operation.
	 * @param action Input value for `action`.
	 * @param gamepadID Input value for `gamepadID`.
	 * @param buttons Input value for `buttons`.
	 * @return Result produced by `removeButtons`, when applicable.
	 */
	static function removeButtons(action:FlxActionDigital, gamepadID:Int, buttons:Array<FlxGamepadInputID>)
	{
		var i = action.inputs.length;
		while (i-- > 0)
		{
			var input = action.inputs[i];
			if (isGamepad(input, gamepadID) && buttons.indexOf(cast input.inputID) != -1)
				action.remove(input);
		}
	}

	/**
	 * Executes the `getInputsFor` operation.
	 * @param control Input value for `control`.
	 * @param device Input value for `device`.
	 * @param list Input value for `list`.
	 * @return Result produced by `getInputsFor`, when applicable.
	 */
	public function getInputsFor(control:Control, device:Device, ?list:Array<Int>):Array<Int>
	{
		if (list == null)
			list = [];

		switch (device)
		{
			case Keys:
				for (input in getActionFromControl(control).inputs)
				{
					if (input.device == KEYBOARD)
						list.push(input.inputID);
				}
			case Gamepad(id):
				for (input in getActionFromControl(control).inputs)
				{
					if (input.deviceID == id)
						list.push(input.inputID);
				}
		}
		return list;
	}

	/**
	 * Executes the `removeDevice` operation.
	 * @param device Input value for `device`.
	 * @return Result produced by `removeDevice`, when applicable.
	 */
	public function removeDevice(device:Device)
	{
		switch (device)
		{
			case Keys:
				setKeyboardScheme(None);
			case Gamepad(id):
				removeGamepad(id);
		}
	}

	/**
	 * Executes the `isDevice` operation.
	 * @param input Input value for `input`.
	 * @param device Input value for `device`.
	 * @return Result produced by `isDevice`, when applicable.
	 */
	static function isDevice(input:FlxActionInput, device:Device)
	{
		return switch device
		{
			case Keys: input.device == KEYBOARD;
			case Gamepad(id): isGamepad(input, id);
		}
	}

	/**
	 * Executes the `isGamepad` operation.
	 * @param input Input value for `input`.
	 * @param deviceID Input value for `deviceID`.
	 * @return Result produced by `isGamepad`, when applicable.
	 */
	inline static function isGamepad(input:FlxActionInput, deviceID:Int)
	{
		return input.device == GAMEPAD && (deviceID == FlxInputDeviceID.ALL || input.deviceID == deviceID);
	}
}
