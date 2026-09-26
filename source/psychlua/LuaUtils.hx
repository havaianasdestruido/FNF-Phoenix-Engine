package psychlua;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.tweens.FlxEase;
import flixel.util.FlxColor;
import play.PlayState;
import states.substates.GameOverSubstate;

import openfl.display.BlendMode;

#if LUA_ALLOWED
import psychlua.FunkinLua.State;
#end

using StringTools;

@:allow(psychlua.FunkinLua)
class LuaUtils {
	// REFACTOR: root classes moved into packages; resolve legacy bare class names from scripts
	/**
	 * Executes the `resolveClassCompat` operation.
	 * @param className Input value for `className`.
	 * @return Result produced by `resolveClassCompat`, when applicable.
	 */
	public static function resolveClassCompat(className:String):Class<Dynamic>
	{
		if (className == null || className.length < 1) return null;
		var cls:Class<Dynamic> = Type.resolveClass(className);
		if (cls != null) return cls;
		var prefixes:Array<String> = ['backend', 'states', 'states.substates', 'objects', 'play', 'play.helpers',
			'data', 'shaders', 'editors', 'editors.charting', 'stages', 'stages.objects', 'options', 'psychlua',
			'psychlua.callbacks', 'psychlua.pystdlib'];
		for (p in prefixes)
		{
			cls = Type.resolveClass(p + '.' + className);
			if (cls != null) return cls;
		}
		return null;
	}

	/**
	 * Executes the `getLuaTween` operation.
	 * @param options Input value for `options`.
	 * @return Result produced by `getLuaTween`, when applicable.
	 */
	public static function getLuaTween(options:Dynamic)
	{
		return (options != null) ? {
			type: getTweenTypeByString(options.type),
			startDelay: options.startDelay,
			onUpdate: options.onUpdate,
			onStart: options.onStart,
			onComplete: options.onComplete,
			loopDelay: options.loopDelay,
			ease: getFlxEaseByString(options.ease)
		} : null;
	}

	//buncho string stuffs
	/**
	 * Executes the `getTweenTypeByString` operation.
	 * @param type Input value for `type`.
	 * @return Result produced by `getTweenTypeByString`, when applicable.
	 */
	public static function getTweenTypeByString(?type:String = '') {
		switch(type.toLowerCase().trim())
		{
			case 'backward': return FlxTweenType.BACKWARD;
			case 'looping'|'loop': return FlxTweenType.LOOPING;
			case 'persist': return FlxTweenType.PERSIST;
			case 'pingpong': return FlxTweenType.PINGPONG;
		}
		return FlxTweenType.ONESHOT;
	}

    //Better optimized than using some getProperty shit or idk
	/**
	 * Executes the `getFlxEaseByString` operation.
	 * @param ease Input value for `ease`.
	 * @return Result produced by `getFlxEaseByString`, when applicable.
	 */
	public static inline function getFlxEaseByString(?ease:String = '') {
		return switch(ease.toLowerCase().trim()) {
			case 'backin': return FlxEase.backIn;
			case 'backinout': return FlxEase.backInOut;
			case 'backout': return FlxEase.backOut;
			case 'bouncein': return FlxEase.bounceIn;
			case 'bounceinout': return FlxEase.bounceInOut;
			case 'bounceout': return FlxEase.bounceOut;
			case 'circin': return FlxEase.circIn;
			case 'circinout': return FlxEase.circInOut;
			case 'circout': return FlxEase.circOut;
			case 'cubein': return FlxEase.cubeIn;
			case 'cubeinout': return FlxEase.cubeInOut;
			case 'cubeout': return FlxEase.cubeOut;
			case 'elasticin': return FlxEase.elasticIn;
			case 'elasticinout': return FlxEase.elasticInOut;
			case 'elasticout': return FlxEase.elasticOut;
			case 'expoin': return FlxEase.expoIn;
			case 'expoinout': return FlxEase.expoInOut;
			case 'expoout': return FlxEase.expoOut;
			case 'quadin': return FlxEase.quadIn;
			case 'quadinout': return FlxEase.quadInOut;
			case 'quadout': return FlxEase.quadOut;
			case 'quartin': return FlxEase.quartIn;
			case 'quartinout': return FlxEase.quartInOut;
			case 'quartout': return FlxEase.quartOut;
			case 'quintin': return FlxEase.quintIn;
			case 'quintinout': return FlxEase.quintInOut;
			case 'quintout': return FlxEase.quintOut;
			case 'sinein': return FlxEase.sineIn;
			case 'sineinout': return FlxEase.sineInOut;
			case 'sineout': return FlxEase.sineOut;
			case 'smoothstepin': return FlxEase.smoothStepIn;
			case 'smoothstepinout': return FlxEase.smoothStepInOut;
			case 'smoothstepout': return FlxEase.smoothStepInOut;
			case 'smootherstepin': return FlxEase.smootherStepIn;
			case 'smootherstepinout': return FlxEase.smootherStepInOut;
			case 'smootherstepout': return FlxEase.smootherStepOut;
			case _: return FlxEase.linear;
		}
	}

	/**
	 * Executes the `blendModeFromString` operation.
	 * @param blend Input value for `blend`.
	 * @return Result produced by `blendModeFromString`, when applicable.
	 */
	public static inline function blendModeFromString(blend:String):BlendMode {
		return switch(blend.toLowerCase().trim()) {
			case 'add': return ADD;
			case 'alpha': return ALPHA;
			case 'darken': return DARKEN;
			case 'difference': return DIFFERENCE;
			case 'erase': return ERASE;
			case 'hardlight': return HARDLIGHT;
			case 'invert': return INVERT;
			case 'layer': return LAYER;
			case 'lighten': return LIGHTEN;
			case 'multiply': return MULTIPLY;
			case 'overlay': return OVERLAY;
			case 'screen': return SCREEN;
			case 'shader': return SHADER;
			case 'subtract': return SUBTRACT;
			case _: return NORMAL;
		}
	}

	/**
	 * Executes the `cameraFromString` operation.
	 * @param cam Input value for `cam`.
	 * @return Result produced by `cameraFromString`, when applicable.
	 */
	public static inline function cameraFromString(cam:String):FlxCamera {
		return switch(cam.toLowerCase()) {
			case 'camhud' | 'hud': return PlayState.instance.camHUD;
			case 'camother' | 'other': return PlayState.instance.camOther;
			case _: PlayState.instance.camGame;
		}
	}
	
	// alias for above, helper function basically
	/**
	 * Executes the `getCam` operation.
	 * @param obj Input value for `obj`.
	 * @return Result produced by `getCam`, when applicable.
	 */
	public static function getCam(obj:String):Dynamic {
        if (obj.toLowerCase().trim() == "global")
		    return FlxG.game;
	    return cameraFromString(obj);
    }

	/**
	 * Executes the `luaTrace` operation.
	 * @param lua Input value for `lua`.
	 * @param text Input value for `text`.
	 * @param ignoreCheck Input value for `ignoreCheck`.
	 * @param deprecated Input value for `deprecated`.
	 * @param color Input value for `color`.
	 * @return Result produced by `luaTrace`, when applicable.
	 */
	public static function luaTrace(lua: #if LUA_ALLOWED State #else Dynamic #end, text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		#if LUA_ALLOWED
		if(ignoreCheck || getBool(lua, 'luaDebugMode')) {
			if(deprecated && !getBool(lua, 'luaDeprecatedWarnings')) {
				return;
			}
			PlayState.instance.addTextToDebug(text, color);
			trace(text);
		}
		#end
	}

	/**
	 * Executes the `getErrorMessage` operation.
	 * @param lua Input value for `lua`.
	 * @param status Input value for `status`.
	 * @return Result produced by `getErrorMessage`, when applicable.
	 */
	public static function getErrorMessage(lua: #if LUA_ALLOWED State #else Dynamic #end, status:Int):String {
		#if LUA_ALLOWED
		var v:String = Lua.tostring(lua, -1);
		Lua.pop(lua, 1);

		if (v != null) v = v.trim();
		if (v == null || v == "")
		{
			switch (status)
			{
				case type if (type == Lua.ERRRUN):
					return "Runtime Error";
				case type if (type == Lua.ERRMEM):
					return "Memory Allocation Error";
				case type if (type == Lua.ERRERR):
					return "Critical Error";
			}
			return "Unknown Error";
		}

		return v;
		#else
		return null;
		#end
	}
	
	/**
	 * Executes the `isOfTypes` operation.
	 * @param value Input value for `value`.
	 * @param types Input value for `types`.
	 * @return Result produced by `isOfTypes`, when applicable.
	 */
	public static function isOfTypes(value:Any, types:Array<Dynamic>)
	{
		for (type in types)
		{
			if(Std.isOfType(value, type)) return true;
		}
		return false;
	}

	/**
	 * Executes the `getBool` operation.
	 * @param lua Input value for `lua`.
	 * @param variable Input value for `variable`.
	 * @return Result produced by `getBool`, when applicable.
	 */
	public static function getBool(lua: #if LUA_ALLOWED State #else Dynamic #end, variable:String) {
		#if LUA_ALLOWED
		var result:String = null;
		Lua.getglobal(lua, variable);
		result = Convert.fromLua(lua, -1);
		Lua.pop(lua, 1);

		if(result == null) {
			return false;
		}
		return (result == 'true');
		#else
		return false;
		#end
	}

	// REFACTOR: moved from FunkinLua; pure/stateless helpers
	/**
	 * Executes the `typeToString` operation.
	 * @param type Input value for `type`.
	 * @return Result produced by `typeToString`, when applicable.
	 */
	public static function typeToString(type:Int):String
	{
		#if LUA_ALLOWED
		switch (type)
		{
			case type if (type == Lua.TBOOLEAN):
				return "boolean";
			case type if (type == Lua.TNUMBER):
				return "number";
			case type if (type == Lua.TSTRING):
				return "string";
			case type if (type == Lua.TTABLE):
				return "table";
			case type if (type == Lua.TFUNCTION):
				return "function";
			case type if (type <= Lua.TNIL):
				return "nil";
		}
		#end
		return "unknown";
	}

	/**
	 * Executes the `getInstance` operation.
	 * @return Result produced by `getInstance`, when applicable.
	 */
	public static inline function getInstance()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}

	/**
	 * Executes the `setVarInArray` operation.
	 * @param instance Input value for `instance`.
	 * @param variable Input value for `variable`.
	 * @param value Input value for `value`.
	 * @return Result produced by `setVarInArray`, when applicable.
	 */
	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
	{
		if(variable.indexOf('[') == -1)
		{
			if(PlayState.instance.variables.exists(variable))
			{
				PlayState.instance.variables.set(variable, value);
				return true;
			}

			Reflect.setProperty(instance, variable, value);
			return true;
		}

		var pathParts:Array<String> = variable.split('[');
		if(pathParts.length > 1)
		{
			var blah:Dynamic = null;
			if(PlayState.instance.variables.exists(pathParts[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(pathParts[0]);
				if(retVal != null)
					blah = retVal;
			}
			else
				blah = Reflect.getProperty(instance, pathParts[0]);

			for (i in 1...pathParts.length)
			{
				var leNum:Dynamic = pathParts[i].substr(0, pathParts[i].length - 1);
				if(i >= pathParts.length-1) //Last array
					blah[leNum] = value;
				else //Anything else
					blah = blah[leNum];
			}
			return blah;
		}
		/*if(Std.isOfType(instance, Map))
			instance.set(variable,value);
		else*/

		if(PlayState.instance.variables.exists(variable))
		{
			PlayState.instance.variables.set(variable, value);
			return true;
		}

		Reflect.setProperty(instance, variable, value);
		return true;
	}
	/**
	 * Executes the `getVarInArray` operation.
	 * @param instance Input value for `instance`.
	 * @param variable Input value for `variable`.
	 * @return Result produced by `getVarInArray`, when applicable.
	 */
	public static function getVarInArray(instance:Dynamic, variable:String):Any
	{
		if(variable.indexOf('[') == -1)
		{
			if(PlayState.instance.variables.exists(variable))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(variable);
				if(retVal != null)
					return retVal;
			}

			return Reflect.getProperty(instance, variable);
		}

		var pathParts:Array<String> = variable.split('[');
		if(pathParts.length > 1)
		{
			var blah:Dynamic = null;
			if(PlayState.instance.variables.exists(pathParts[0]))
			{
				var retVal:Dynamic = PlayState.instance.variables.get(pathParts[0]);
				if(retVal != null)
					blah = retVal;
			}
			else
				blah = Reflect.getProperty(instance, pathParts[0]);

			for (i in 1...pathParts.length)
			{
				var leNum:Dynamic = pathParts[i].substr(0, pathParts[i].length - 1);
				blah = blah[leNum];
			}
			return blah;
		}

		if(PlayState.instance.variables.exists(variable))
		{
			var retVal:Dynamic = PlayState.instance.variables.get(variable);
			if(retVal != null)
				return retVal;
		}

		return Reflect.getProperty(instance, variable);
	}

	/**
	 * Executes the `getObjectDirectly` operation.
	 * @param objectName Input value for `objectName`.
	 * @param checkForTextsToo Input value for `checkForTextsToo`.
	 * @return Result produced by `getObjectDirectly`, when applicable.
	 */
	public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true):Dynamic
	{
		var coverMeInPiss:Dynamic = PlayState.instance.getLuaObject(objectName, checkForTextsToo);
		if(coverMeInPiss==null)
			coverMeInPiss = getVarInArray(getInstance(), objectName);

		return coverMeInPiss;
	}

	/**
	 * Executes the `getPropertyLoopThingWhatever` operation.
	 * @param killMe Input value for `killMe`.
	 * @param checkForTextsToo Input value for `checkForTextsToo`.
	 * @param getProperty Input value for `getProperty`.
	 * @return Result produced by `getPropertyLoopThingWhatever`, when applicable.
	 */
	public static function getPropertyLoopThingWhatever(killMe:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool=true):Dynamic
	{
		var coverMeInPiss:Dynamic = getObjectDirectly(killMe[0], checkForTextsToo);
		var end = killMe.length;
		if(getProperty)end=killMe.length-1;

		for (i in 1...end) {
			coverMeInPiss = getVarInArray(coverMeInPiss, killMe[i]);
		}
		return coverMeInPiss;
	}

	/**
	 * Executes the `addAnimByIndices` operation.
	 * @param obj Input value for `obj`.
	 * @param name Input value for `name`.
	 * @param prefix Input value for `prefix`.
	 * @param indices Input value for `indices`.
	 * @param framerate Input value for `framerate`.
	 * @param loop Input value for `loop`.
	 * @return Result produced by `addAnimByIndices`, when applicable.
	 */
	public static function addAnimByIndices(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false)
	{
		var strIndices:Array<String> = indices.trim().split(',');
		var die:Array<Int> = [];
		for (i in 0...strIndices.length) {
			die.push(Std.parseInt(strIndices[i]));
		}

		if(PlayState.instance.getLuaObject(obj, false)!=null) {
			var pussy:FlxSprite = PlayState.instance.getLuaObject(obj, false);
			pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
			if(pussy.animation.curAnim == null) {
				pussy.animation.play(name, true);
			}
			return true;
		}

		var pussy:FlxSprite = Reflect.getProperty(getInstance(), obj);
		if(pussy != null) {
			pussy.animation.addByIndices(name, prefix, die, '', framerate, loop);
			if(pussy.animation.curAnim == null) {
				pussy.animation.play(name, true);
			}
			return true;
		}
		return false;
	}
}