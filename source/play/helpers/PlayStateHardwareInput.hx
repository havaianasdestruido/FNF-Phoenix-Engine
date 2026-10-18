package play.helpers;

#if android
import android.platform.AndroidHardwareInput;
import backend.ClientPrefs;
import backend.HardwareKeys;
import flixel.input.keyboard.FlxKey;
import play.PlayState;
import play.helpers.PlayStateInput;

/**
 * Gameplay input for hardware triggers (Android volume keys) bound in the
 * keybind menu's HARDWARE section. Each note lane can have up to two triggers,
 * stored in ClientPrefs.keyBinds as `hw_note_<lane>`.
 *
 * Volume keys are only intercepted while gameplay is live: not paused, with at
 * least one trigger bound. Everywhere else the system volume keeps working.
 */
@:access(play.PlayState)
class PlayStateHardwareInput
{
	/** Keybind names of the note lanes, in lane order (same order as keysArray). */
	public static final LANE_BINDS:Array<String> = ['hw_note_left', 'hw_note_down', 'hw_note_up', 'hw_note_right'];

	/** True when at least one hardware trigger is bound to a note lane. */
	public static function hasBindings():Bool
	{
		for (name in LANE_BINDS)
		{
			var binds:Array<FlxKey> = ClientPrefs.keyBinds.get(name);
			if (binds == null)
				continue;
			for (key in binds)
				if (HardwareKeys.isBind(key))
					return true;
		}
		return false;
	}

	/** Note lane bound to the hardware key code, or -1. */
	public static function laneForKeyCode(keyCode:Int):Int
	{
		for (lane in 0...LANE_BINDS.length)
		{
			var binds:Array<FlxKey> = ClientPrefs.keyBinds.get(LANE_BINDS[lane]);
			if (binds == null)
				continue;
			for (key in binds)
				if (HardwareKeys.isBind(key) && HardwareKeys.keyCodeOf(key) == keyCode)
					return lane;
		}
		return -1;
	}

	/** Handles AndroidHardwareInput.onKey while gameplay is running. */
	public static function onHardwareKey(state:PlayState, keyCode:Int, down:Bool):Void
	{
		var lane:Int = laneForKeyCode(keyCode);
		if (lane < 0)
			return;

		if (down)
		{
			// Key repeat events arrive while the trigger is held; only the first one is a press.
			if (state.hardwareHeld[lane])
				return;
			state.hardwareHeld[lane] = true;
			PlayStateInput.keyPressed(state, lane);
		}
		else
		{
			if (!state.hardwareHeld[lane])
				return;
			state.hardwareHeld[lane] = false;
			PlayStateInput.keyReleased(state, lane);
		}
	}

	/** Keeps sustain notes sustained while a bound trigger is held down. */
	public static function applyHeld(state:PlayState):Void
	{
		for (lane in 0...state.hardwareHeld.length)
			if (state.hardwareHeld[lane])
				state.holdArray[lane] = true;
	}

	/**
	 * Captures volume keys only while gameplay is live; releases them otherwise.
	 * @param covered true while a substate is being opened (pause, game over, ...): flixel
	 *                only assigns `subState` on the next update, so the caller says so.
	 */
	public static function syncVolumeKeys(state:PlayState, covered:Bool = false):Void
	{
		var wanted:Bool = !covered && state.subState == null && !state.paused && !state.cpuControlled && hasBindings();
		if (wanted == AndroidHardwareInput.areVolumeKeysEnabled())
			return;

		if (wanted)
			AndroidHardwareInput.enableVolumeKeys();
		else
		{
			// Releases that happen while the keys are handed back to the system are never
			// delivered, so forget held triggers to avoid stuck sustains after resume.
			clearHeld(state);
			AndroidHardwareInput.disableVolumeKeys();
		}
	}

	/** Called when the gameplay state is destroyed. */
	public static function release(state:PlayState):Void
	{
		clearHeld(state);
		if (AndroidHardwareInput.areVolumeKeysEnabled())
			AndroidHardwareInput.disableVolumeKeys();
	}

	static function clearHeld(state:PlayState):Void
	{
		for (lane in 0...state.hardwareHeld.length)
			state.hardwareHeld[lane] = false;
	}
}
#end
