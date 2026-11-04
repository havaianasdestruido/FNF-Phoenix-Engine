package states.substates;

import backend.MusicBeatSubstate;
import psychlua.StateScripts;

/**
 * Blank `MusicBeatSubstate` whose behaviour comes entirely from
 * `data/states/<name>.hx`. Use `StateScripts.openSubState("MyPause")` or
 * `openModSubState("MyPause")` from Lua/Python/HScript.
 */
class ModSubState extends MusicBeatSubstate
{
	/** Last script name passed to a ModSubState. */
	public static var lastName:String = null;
	/** Last extra payload passed to a ModSubState. */
	public static var lastData:Dynamic = null;

	/** Extra data forwarded from the opener (JSON-friendly). */
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
