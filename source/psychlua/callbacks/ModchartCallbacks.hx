package psychlua.callbacks;

import modchart.ModchartEase;
import modchart.ModchartEvent;
import modchart.ModchartManager;
import modchart.ModifierRegistry;
import play.PlayState;
import psychlua.FunkinLua;
import headers.PsychLua;

/**
 * FunkinModchart-style scripting API for Lua (mirrored for Python in
 * `psychlua.pystdlib.PyModchartLib`). See `docs/MODCHART.md`.
 *
 * Modifiers are installed per playfield (`addModifier`), their percents are
 * per player (`setPercent`), and the beat timeline schedules changes
 * (`modSet`/`modEase`/`modAdd`/`modSetAdd`/`modCallback`/`modRepeater`).
 * `player = -1` means both sides, `field = -1` means every playfield.
 */
class ModchartCallbacks
{
	public static function register(funk:FunkinLua):Void
	{
		@:privateAccess {
			FunkinLua.registerFunction("addModifier", function(mod:String, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager == null)
					return false;
				if (!ModifierRegistry.exists(mod))
				{
					LuaUtils.luaTrace(funk.lua, 'addModifier: unknown modifier "$mod" (see docs/MODCHART.md for the list)', false, false, FlxColor.RED);
					return false;
				}
				return manager.addModifier(mod, field);
			});

			FunkinLua.registerFunction("setPercent", function(mod:String, value:Float, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.setPercent(mod, value, player, field);
			});

			FunkinLua.registerFunction("getPercent", function(mod:String, ?player:Int = 0, ?field:Int = 0) {
				final manager:ModchartManager = getManager();
				return manager == null ? 0 : manager.getPercent(mod, player, field);
			});

			FunkinLua.registerFunction("modSet", function(mod:String, beat:Float, value:Float, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.set(mod, beat, value, player, field);
			});

			FunkinLua.registerFunction("modEase", function(mod:String, beat:Float, length:Float, value:Float, ease:String, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.ease(mod, beat, length, value, ModchartEase.byName(ease), player, field);
			});

			FunkinLua.registerFunction("modAdd", function(mod:String, beat:Float, length:Float, addition:Float, ease:String, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.add(mod, beat, length, addition, ModchartEase.byName(ease), player, field);
			});

			FunkinLua.registerFunction("modSetAdd", function(mod:String, beat:Float, valueToAdd:Float, ?player:Int = -1, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.setAdd(mod, beat, valueToAdd, player, field);
			});

			FunkinLua.registerFunction("modCallback", function(beat:Float, callbackName:String, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.callback(beat, function(event:ModchartEvent) PlayState.instance.callOnLuas(callbackName, [event.fireBeat]), field);
			});

			FunkinLua.registerFunction("modRepeater", function(beat:Float, length:Float, callbackName:String, ?field:Int = -1) {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.repeater(beat, length, function(event:ModchartEvent) PlayState.instance.callOnLuas(callbackName, [event.fireBeat]), field);
			});

			FunkinLua.registerFunction("addPlayfield", function() {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.addPlayfield();
			});

			FunkinLua.registerFunction("resetModchart", function() {
				final manager:ModchartManager = getManager();
				if (manager != null)
					manager.clear();
			});

			FunkinLua.registerFunction("isModchartActive", function() {
				final manager:ModchartManager = getManager();
				return manager != null && manager.isActive();
			});

			FunkinLua.registerFunction("getModchartModifiers", function() {
				final manager:ModchartManager = getManager();
				return manager == null ? [] : manager.modifierNames();
			});

			FunkinLua.registerFunction("setModchartPerspective", function(enabled:Bool, ?fovDegrees:Float = 90, ?zScale:Float = 1) {
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
