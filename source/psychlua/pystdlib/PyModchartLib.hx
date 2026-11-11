package psychlua.pystdlib;

import modchart.ModchartEase;
import modchart.ModchartEvent;
import modchart.ModchartManager;
import modchart.ModifierRegistry;
import play.PlayState;
import psychlua.PythonScript;

/**
 * Python mirror of `psychlua.callbacks.ModchartCallbacks` (same function
 * names and argument order, per the Lua/Python parity rule). See
 * `docs/MODCHART.md`.
 */
class PyModchartLib
{
	public static function register(py:PythonScript):Void
	{
		@:privateAccess {
			PythonScript.registerFunction("addModifier", function(mod:String, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager == null)
					return false;
				if (!ModifierRegistry.exists(mod))
				{
					py.pyTrace('addModifier: unknown modifier "$mod" (see docs/MODCHART.md for the list)', false, false, FlxColor.RED);
					return false;
				}
				return manager.addModifier(mod, field);
			});

			PythonScript.registerFunction("setPercent", function(mod:String, value:Float, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.setPercent(mod, value, player, field);
			});

			PythonScript.registerFunction("getPercent", function(mod:String, ?player:Int = 0, ?field:Int = 0) {
				final manager:ModchartManager = getManager();
				return manager == null ? 0 : manager.getPercent(mod, player, field);
			});

			PythonScript.registerFunction("modSet", function(mod:String, beat:Float, value:Float, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.set(mod, beat, value, player, field);
			});

			PythonScript.registerFunction("modEase", function(mod:String, beat:Float, length:Float, value:Float, ease:String, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.ease(mod, beat, length, value, ModchartEase.byName(ease), player, field);
			});

			PythonScript.registerFunction("modAdd", function(mod:String, beat:Float, length:Float, addition:Float, ease:String, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.add(mod, beat, length, addition, ModchartEase.byName(ease), player, field);
			});

			PythonScript.registerFunction("modSetAdd", function(mod:String, beat:Float, valueToAdd:Float, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.setAdd(mod, beat, valueToAdd, player, field);
			});

			PythonScript.registerFunction("modCallback", function(beat:Float, callbackName:String, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.callback(beat, function(event:ModchartEvent) PlayState.instance.callOnLuas(callbackName, [event.fireBeat]), field);
			});

			PythonScript.registerFunction("modRepeater", function(beat:Float, length:Float, callbackName:String, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.repeater(beat, length, function(event:ModchartEvent) PlayState.instance.callOnLuas(callbackName, [event.fireBeat]), field);
			});

			PythonScript.registerFunction("addPlayfield", function() {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.addPlayfield();
			});

			PythonScript.registerFunction("resetModchart", function() {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.clear();
			});

			PythonScript.registerFunction("isModchartActive", function() {
				final manager:ModchartManager = getManager();
				return manager != null && manager.isActive();
			});

			PythonScript.registerFunction("getModchartModifiers", function() {
				final manager:ModchartManager = getManager();
				return manager == null ? [] : manager.modifierNames();
			});

			PythonScript.registerFunction("setModchartPerspective", function(enabled:Bool, ?fovDegrees:Float = 90, ?zScale:Float = 1) {
				final manager:ModchartManager = getManager();
				if (manager == null)
					return;
				for (field in manager.playfields)
				{
					field.usePerspective = enabled;
					field.fov = fovDegrees * Math.PI / 180;
					field.zScale = zScale;
				}
			});
		}
	}

	static function getManager():ModchartManager
	{
		return PlayState.instance == null ? null : PlayState.instance.modchart;
	}
}
