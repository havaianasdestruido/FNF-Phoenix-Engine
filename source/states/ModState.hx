package states;

import backend.MusicBeatState;
import psychlua.StateScripts;

/**
 * Blank `MusicBeatState` whose behaviour comes entirely from
 * `data/states/<name>.hx`. Use `StateScripts.switchState("MyMenu")` or
 * `switchCustomState("MyMenu")` from Lua/Python/HScript.
 */
class ModState extends MusicBeatState
{
	/** Last script name passed to a ModState. Used across `FlxG.resetState()`. */
	public static var lastName:String = null;
	/** Last extra payload passed to a ModState. */
	public static var lastData:Dynamic = null;

	/** Extra data forwarded from the previous screen (JSON-friendly). */
	public var data:Dynamic = null;

	public function new(?stateName:String, ?data:Dynamic)
	{
		super();
		if (stateName != null && stateName.length > 0 && stateName != lastName)
		{
			lastName = StateScripts.sanitizeName(stateName);
			lastData = null;
		}
		if (data != null)
			lastData = data;

		this.data = lastData;
		this.scriptName = lastName;
		this.scriptsAllowed = true;
	}
}
