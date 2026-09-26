package psychlua;

import flixel.FlxBasic;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.math.FlxMath;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import flixel.util.FlxAxes;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

import openfl.display.BlendMode;

import paopao.hython.Expr.Error;
import paopao.hython.Interp;
import paopao.hython.Parser;

import backend.Paths;
import play.PlayState;
import states.substates.GameOverSubstate;
import psychlua.pystdlib.PyCameraLib;
import psychlua.pystdlib.PyCharacterLib;
import psychlua.pystdlib.PyKeyLib;
import psychlua.pystdlib.PyMiscLib;
import psychlua.pystdlib.PyPropertyLib;
import psychlua.pystdlib.PyScoreLib;
import psychlua.pystdlib.PySoundLib;
import psychlua.pystdlib.PySpriteLib;
import psychlua.pystdlib.PyTextLib;
import psychlua.pystdlib.PyTimerLib;
import psychlua.pystdlib.PyTweenLib;
import Type.ValueType;

import objects.Character;

#if DISCORD_ALLOWED
import backend.DiscordClient;
#end

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

#if sys
import sys.FileSystem;
import sys.io.File;
#end

using StringTools;

/**
 * A Python script running inside the engine, powered by the pure-Haxe
 * Hython interpreter (haxelib `hython`). Mirrors `FunkinLua`'s API so Python
 * mods behave exactly like Lua mods: define top-level `def` callbacks
 * (onCreate, onUpdate, goodNoteHit, ...), call the same engine functions and
 * return the same sentinels (`Function_Stop`, `Function_Continue`,
 * `Function_StopAll`).
 */
#if PYTHON_ALLOWED
class PythonScript
{
	// Sentinel strings are intentionally the SAME values as FunkinLua's so the
	// existing `ret != FunkinLua.Function_Stop` checks keep working for Python.
	public static var Function_Stop:Dynamic = "##PSYCHLUA_FUNCTIONSTOP";
	public static var Function_Continue:Dynamic = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static var Function_StopAll:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";

	public var scriptName:String = '';
	public var closed:Bool = false;
	public var lastCalledFunction:String = '';
	public static var lastCalledScript:PythonScript = null;

	public static var customFunctions:Map<String, Dynamic> = [];
	public static var registeredFunctions:Map<String, Dynamic> = [];

	var interp:Interp;
	var parser:Parser;
	var _missingCalls:Map<String, Bool> = new Map();

	/**
	 * Executes the `new` operation.
	 * @param scriptName Input value for `scriptName`.
	 * @param scriptCode Input value for `scriptCode`.
	 */
	public function new(scriptName:String, ?scriptCode:String)
	{
		this.scriptName = scriptName;
		final game:PlayState = PlayState.instance;
		game.pythonArray.push(this);

		interp = new Interp();
		parser = new Parser();

		var code:String = scriptCode;
		if (code == null)
		{
			#if sys
			if (FileSystem.exists(scriptName))
				code = File.getContent(scriptName);
			else
			#end
				code = Paths.getTextFromFile(scriptName);
		}
		// hython's lexer miscounts indentation on CRLF files, normalize to LF
		code = code.split("\r\n").join("\n");

		try
		{
			interp.execute(parser.parseString(code));
		}
		catch (e:Error)
		{
			pyTrace('Error loading python script: "$scriptName"\n' + getErrorString(e), true, false, FlxColor.RED);
			closed = true;
			return;
		}
		catch (e:Dynamic)
		{
			pyTrace('Error loading python script: "$scriptName"\n' + Std.string(e), true, false, FlxColor.RED);
			closed = true;
			return;
		}

		pyTrace('python file loaded succesfully: ' + scriptName, true);

		// Python globals
		set('Function_StopAll', Function_StopAll);
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('pythonDebugMode', false);
		set('pythonDeprecatedWarnings', true);

		// Bind every registered/custom function into the interpreter, then let
		// other systems add their own callbacks (CustomSubstate, Achievements...).
		registerCustomFunctions();
		CustomSubstate.implementPython(this);
		#if ACHIEVEMENTS_ALLOWED Achievements.addPythonCallbacks(this); #end
		#if flxanimate FlxAnimateFunctions.implementPython(this); #end

		// --------------------------------------------------------------------
		// API registry (mirrors FunkinLua's constructor).
		// --------------------------------------------------------------------

// REFACTOR: extracted to psychlua.pystdlib.PyPropertyLib
	PyPropertyLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyScoreLib
	PyScoreLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyCharacterLib
	PyCharacterLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyCameraLib
	PyCameraLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyKeyLib
	PyKeyLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PySpriteLib
	PySpriteLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyTextLib
	PyTextLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyTweenLib
	PyTweenLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyTimerLib
	PyTimerLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PySoundLib
	PySoundLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyMiscLib
	PyMiscLib.register(this);

	}

	// -------------------------------------------------------------------- //
	//                            INTERNALS                                 //
	// -------------------------------------------------------------------- //

	/**
	 * Executes the `call` operation.
	 * @param func Input value for `func`.
	 * @param args Input value for `args`.
	 * @return Result produced by `call`, when applicable.
	 */
	public function call(func:String, args:Array<Dynamic>):Dynamic {
		if (closed) return Function_Continue;

		lastCalledFunction = func;
		lastCalledScript = this;

		if (_missingCalls.exists(func)) return Function_Continue;

		try {
			if (interp == null || !interp.getdef(func)) {
				_missingCalls.set(func, true);
				return Function_Continue;
			}

			var result:Dynamic = interp.calldef(func, args);
			if (result == null) result = Function_Continue;
			return result;
		}
		catch (e:Error) {
			pyTrace("ERROR (" + func + "): " + getErrorString(e), false, false, FlxColor.RED);
			_missingCalls.set(func, true);
			return Function_Continue;
		}
		catch (e:Dynamic) {
			pyTrace("ERROR (" + func + "): " + Std.string(e), false, false, FlxColor.RED);
			_missingCalls.set(func, true);
			return Function_Continue;
		}
	}

	/**
	 * Executes the `set` operation.
	 * @param variable Input value for `variable`.
	 * @param data Input value for `data`.
	 * @return Result produced by `set`, when applicable.
	 */
	public function set(variable:String, data:Dynamic) {
		if (closed) return;

		_missingCalls.remove(variable);
		try {
			interp.setVar(variable, data);
		}
		catch (e:Error) {
			pyTrace("ERROR (set " + variable + "): " + getErrorString(e), false, false, FlxColor.RED);
		}
		catch (e:Dynamic) {
			pyTrace("ERROR (set " + variable + "): " + Std.string(e), false, false, FlxColor.RED);
		}
	}

	/**
	 * Executes the `get` operation.
	 * @param variable Input value for `variable`.
	 * @return Result produced by `get`, when applicable.
	 */
	public function get(variable:String):Dynamic {
		if (closed) return null;
		try {
			return interp.getVar(variable);
		}
		catch (e:Error) {
			return null;
		}
		catch (e:Dynamic) {
			return null;
		}
	}

	/**
	 * Executes the `stop` operation.
	 * @return Result produced by `stop`, when applicable.
	 */
	public function stop() {
		closed = true;
		if (interp == null) return;
		try {
			interp.stop();
		}
		catch (e:Dynamic) {
			// ignore
		}
	}

	/**
	 * Executes the `pyTrace` operation.
	 * @param text Input value for `text`.
	 * @param ignoreCheck Input value for `ignoreCheck`.
	 * @param deprecated Input value for `deprecated`.
	 * @param color Input value for `color`.
	 * @return Result produced by `pyTrace`, when applicable.
	 */
	public function pyTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		if (ignoreCheck || getVar('pythonDebugMode')) {
			if (deprecated && !getVar('pythonDeprecatedWarnings')) {
				return;
			}
			PlayState.instance.addTextToDebug(text, color);
			trace(text);
		}
	}

	/**
	 * Executes the `getVar` operation.
	 * @param variable Input value for `variable`.
	 * @return Result produced by `getVar`, when applicable.
	 */
	public function getVar(variable:String):Dynamic {
		if (closed) return false;
		try {
			var result:Dynamic = interp.getVar(variable);
			if (result == null) {
				return false;
			}
			return result;
		}
		catch (e:Error) {
			return false;
		}
		catch (e:Dynamic) {
			return false;
		}
	}

	/**
	 * Executes the `getErrorString` operation.
	 * @param e Input value for `e`.
	 * @return Result produced by `getErrorString`, when applicable.
	 */
	static function getErrorString(e:Error):String {
		return switch (e) {
			case EUnknownVariable(v): "NameError: name '" + v + "' is not defined";
			case EInvalidAccess(f): "AttributeError: cannot access field '" + f + "'";
			case EKeyError(msg): "KeyError: " + msg;
			case ETypeError(msg): "TypeError: " + msg;
			case EValueError(msg): "ValueError: " + msg;
			case EZeroDivisionError(msg): "ZeroDivisionError: " + msg;
			case ENameError(msg): "NameError: " + msg;
			case EAssertionError(msg): "AssertionError: " + msg;
			case ERecursionError(msg): "RecursionError: " + msg;
			case EInvalidOp(op): "SyntaxError: invalid operation '" + op + "'";
			case ESyntaxError(msg): "SyntaxError: " + msg;
			case EUnterminatedString: "SyntaxError: unterminated string literal";
			case EUnterminatedComment: "SyntaxError: unterminated comment";
			case EInvalidChar(c): "SyntaxError: invalid character '" + String.fromCharCode(c) + "'";
			case EInvalidIterator(v): "TypeError: '" + v + "' object is not iterable";
			case ETabError(msg): "TabError: " + msg;
			case ECustom(msg): Std.string(msg);
			case EExitException(code): "SystemExit: " + code;
			case EClassNotAllowed(msg): msg;
			case EInvalidPreprocessor(msg): msg;
			case EUnexpected(s): "SyntaxError: unexpected '" + s + "'";
		}
	}

	/**
	 * Executes the `registerFunction` operation.
	 * @param name Input value for `name`.
	 * @param func Input value for `func`.
	 */
	public static function registerFunction(name:String, func:Dynamic):Void
		registeredFunctions.set(name, func);

	/**
	 * Executes the `isOfTypes` operation.
	 * @param value Input value for `value`.
	 * @param types Input value for `types`.
	 * @return Result produced by `isOfTypes`, when applicable.
	 */
	public static function isOfTypes(value:Any, types:Array<Dynamic>) {
		for (type in types) {
			if (Std.isOfType(value, type)) return true;
		}
		return false;
	}

	/**
	 * Executes the `registerCustomFunctions` operation.
	 * @return Result produced by `registerCustomFunctions`, when applicable.
	 */
	function registerCustomFunctions() {
		for (name => func in customFunctions) {
			if (func != null) {
				_missingCalls.remove(name);
				set(name, func);
			}
		}
	}

	/**
	 * Executes the `addLocalCallback` operation.
	 * @param name Input value for `name`.
	 * @param myFunction Input value for `myFunction`.
	 * @return Result produced by `addLocalCallback`, when applicable.
	 */
	function addLocalCallback(name:String, myFunction:Dynamic) {
		_missingCalls.remove(name);
		set(name, myFunction);
	}

	// -------------------------------------------------------------------- //
	//                          HELPERS                                     //
	// -------------------------------------------------------------------- //

	/**
	 * Executes the `getInstance` operation.
	 * @return Result produced by `getInstance`, when applicable.
	 */
	function getInstance():Dynamic {
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}

	/**
	 * Executes the `getTextObject` operation.
	 * @param name Input value for `name`.
	 * @return Result produced by `getTextObject`, when applicable.
	 */
	inline function getTextObject(name:String):FlxText {
		return PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : Reflect.getProperty(PlayState.instance, name);
	}

	/**
	 * Executes the `getGroupStuff` operation.
	 * @param leArray Input value for `leArray`.
	 * @param variable Input value for `variable`.
	 * @return Result produced by `getGroupStuff`, when applicable.
	 */
	function getGroupStuff(leArray:Dynamic, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			switch(Type.typeof(coverMeInPiss)) {
				case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
					return coverMeInPiss.get(killMe[killMe.length-1]);
				default:
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			}
		}
		switch(Type.typeof(leArray)) {
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				return leArray.get(variable);
			default:
				return Reflect.getProperty(leArray, variable);
		}
	}

	/**
	 * Executes the `setGroupStuff` operation.
	 * @param leArray Input value for `leArray`.
	 * @param variable Input value for `variable`.
	 * @param value Input value for `value`.
	 * @return Result produced by `setGroupStuff`, when applicable.
	 */
	function setGroupStuff(leArray:Dynamic, variable:String, value:Dynamic) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			Reflect.setProperty(coverMeInPiss, killMe[killMe.length-1], value);
			return;
		}
		Reflect.setProperty(leArray, variable, value);
	}

	/**
	 * Executes the `loadFrames` operation.
	 * @param spr Input value for `spr`.
	 * @param image Input value for `image`.
	 * @param spriteType Input value for `spriteType`.
	 * @return Result produced by `loadFrames`, when applicable.
	 */
	function loadFrames(spr:FlxSprite, image:String, spriteType:String) {
		switch(spriteType.toLowerCase().trim()) {
			case 'aseprite' | 'jsoni8':
				spr.frames = Paths.getAsepriteAtlas(image);
			case 'packer' | 'packeratlas' | 'pac':
				spr.frames = Paths.getPackerAtlas(image);
			default:
				spr.frames = Paths.getSparrowAtlas(image);
		}
	}

	/**
	 * Executes the `resetTextTag` operation.
	 * @param tag Input value for `tag`.
	 * @return Result produced by `resetTextTag`, when applicable.
	 */
	function resetTextTag(tag:String) {
		if(!PlayState.instance.modchartTexts.exists(tag)) {
			return;
		}

		var pee:FlxText = PlayState.instance.modchartTexts.get(tag);
		if(pee != null)
			PlayState.instance.remove(pee, true);

		pee.destroy();
		PlayState.instance.modchartTexts.remove(tag);
	}

	/**
	 * Executes the `resetSpriteTag` operation.
	 * @param tag Input value for `tag`.
	 * @return Result produced by `resetSpriteTag`, when applicable.
	 */
	function resetSpriteTag(tag:String) {
		if(!PlayState.instance.modchartSprites.exists(tag)) {
			return;
		}

		var pee:ModchartSprite = PlayState.instance.modchartSprites.get(tag);
		pee.kill();
		if(pee.wasAdded) {
			PlayState.instance.remove(pee, true);
		}
		pee.destroy();
		PlayState.instance.modchartSprites.remove(tag);
	}

	/**
	 * Executes the `cancelTween` operation.
	 * @param tag Input value for `tag`.
	 * @return Result produced by `cancelTween`, when applicable.
	 */
	function cancelTween(tag:String) {
		if(PlayState.instance.modchartTweens.exists(tag)) {
			PlayState.instance.modchartTweens.get(tag).cancel();
			PlayState.instance.modchartTweens.get(tag).destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
	}

	/**
	 * Executes the `tweenPrepare` operation.
	 * @param tag Input value for `tag`.
	 * @param vars Input value for `vars`.
	 * @return Result produced by `tweenPrepare`, when applicable.
	 */
	function tweenPrepare(tag:String, vars:String) {
		if (tag != null) cancelTween(tag);
		var variables:Array<String> = vars.split('.');
		var sexyProp:Dynamic = FunkinLua.getObjectDirectly(variables[0]);
		if(variables.length > 1)
			sexyProp = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(variables), variables[variables.length-1]);

		return sexyProp;
	}

	/**
	 * Executes the `cancelTimer` operation.
	 * @param tag Input value for `tag`.
	 * @return Result produced by `cancelTimer`, when applicable.
	 */
	function cancelTimer(tag:String) {
		if(PlayState.instance.modchartTimers.exists(tag)) {
			PlayState.instance.modchartTimers.get(tag).cancel();
			PlayState.instance.modchartTimers.remove(tag);
		}
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
	static function addAnimByIndices(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false) {
		var spr:FlxSprite = PlayState.instance.getLuaObject(obj, false);
		if(spr == null) {
			spr = Reflect.getProperty(PlayState.instance, obj);
		}

		if(spr != null) {
			var _indices:Array<Int> = [];
			for (ind in indices.split(',')) {
				_indices.push(Std.parseInt(ind));
			}
			spr.animation.addByIndices(name, prefix, _indices, '', framerate, loop);
			if(spr.animation.curAnim == null) {
				spr.animation.play(name, true);
			}
			return true;
		}
		return false;
	}

	/**
	 * Executes the `getInstanceStatic` operation.
	 * @return Result produced by `getInstanceStatic`, when applicable.
	 */
	public static inline function getInstanceStatic()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}
}
#end
