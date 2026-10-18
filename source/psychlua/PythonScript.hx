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

import backend.ClientPrefs;
import backend.Conductor;
import backend.CoolUtil;
import backend.Mods;
import objects.NoteHelpers;
import backend.Paths;
import backend.ModSecurity;
import backend.WeekData;
import objects.NoteSplash;
import play.PlayState;
import states.MainMenuState;
import states.substates.GameOverSubstate;
import psychlua.pystdlib.PyCameraLib;
import psychlua.pystdlib.PyCharacterLib;
import psychlua.pystdlib.PyHardwareLib;
import psychlua.pystdlib.PyKeyLib;
import psychlua.pystdlib.PyMiscLib;
import psychlua.pystdlib.PyPropertyLib;
import psychlua.pystdlib.PyScoreLib;
import psychlua.pystdlib.PySoundLib;
import psychlua.pystdlib.PySpriteLib;
import psychlua.pystdlib.PyTextLib;
import psychlua.pystdlib.PyTimerLib;
import utils.CoolSystemStuff;
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
	// Lua-compatible alias (#51): the documentation and the shared hook
	// table tell Python authors to `return Function_StopLua`; it carries the
	// same sentinel, so PlayState's Function_StopAll comparison matches it.
	public static var Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";

	public var scriptName:String = '';
	public var modFolder:String = null;
	public var closed:Bool = false;
	public var lastCalledFunction:String = '';
	public static var lastCalledScript:PythonScript = null;

	/** Runtime half of the softmod sandbox; set before Hython is created. */
	public var sandboxed:Bool = false;
	public var securityModName:String = null;
	public var securityAllowlist:Array<String> = [];

	public static var customFunctions:Map<String, Dynamic> = [];
	public static var registeredFunctions:Map<String, Dynamic> = [];

	var interp:Interp;
	var parser:Parser;
	var _missingCalls:Map<String, Bool> = new Map();

	public function new(scriptName:String, ?scriptCode:String)
	{
		this.scriptName = scriptName;
		final game:PlayState = PlayState.instance;

		var code:String = scriptCode;
		if(code == null)
		{
			#if sys
			try
			{
				if(FileSystem.exists(scriptName)) code = File.getContent(scriptName);
			}
			catch(e:Dynamic) {}
			#end
			if(code == null) code = Paths.getTextFromFile(scriptName);
		}

		// Security is intentionally checked before creating the interpreter,
		// registering callbacks, or running any top-level Python statement.
		var security = ModSecurity.checkScript(scriptName, code, 'python');
		sandboxed = security.sandboxed;
		securityModName = security.modName;
		securityAllowlist = security.allowlist;
		modFolder = security.modFolder;
		ModSecurity.report(security, function(message:String) game.addTextToDebug(message, FlxColor.RED));
		if(security.findings.length > 0)
		{
			closed = true;
			return;
		}
		if(code == null)
		{
			closed = true;
			pyTrace('Error loading python script: "$scriptName"\nSource file could not be read.', true, false, FlxColor.RED);
			return;
		}

		interp = new Interp();
		parser = new Parser();
		if(sandboxed)
		{
			// Imports are syntactic and covered by the source denylist; host Haxe
			// class resolution is dynamic, so enforce that restriction at runtime.
			interp.allowClassResolve = false;
		}
		game.pythonArray.push(this);

		// Hython's lexer miscounts indentation on CRLF files, normalize to LF.
		// This preserves line count, as does preprocessHythonCode().
		code = code.split("\r\n").join("\n");
		code = preprocessHythonCode(code);

		// Python globals
		set('Function_StopAll', Function_StopAll);
		set('Function_StopLua', Function_StopLua); // #51
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('pythonDebugMode', false);
		set('pythonDeprecatedWarnings', true);
		set('inChartEditor', false);

		set('modFolder', modFolder);

		// Initial engine state — mirrors FunkinLua so Python has the same starting
		// context for onCreate (curBeat, song metadata, characters, preferences...).
		// Each value is also kept current via PlayState.setOnScripts throughout the song.
		if (PlayState.SONG != null)
		{
			set('curBpm', Conductor.bpm);
			set('bpm', PlayState.SONG.bpm);
			set('scrollSpeed', PlayState.SONG.speed);
			set('crochet', Conductor.crochet);
			set('stepCrochet', Conductor.stepCrochet);
			set('songLength', (FlxG.sound.music != null ? FlxG.sound.music.length : 0));
			set('songName', PlayState.SONG.song);
			set('songPath', Paths.formatToSongPath(PlayState.SONG.song));
			set('startedCountdown', false);
			set('curStage', PlayState.SONG.stage);
			set('isStoryMode', PlayState.isStoryMode);
			set('difficulty', PlayState.storyDifficulty);
			var difficultyName:String = CoolUtil.difficulties[PlayState.storyDifficulty];
			set('difficultyName', difficultyName);
			set('difficultyPath', Paths.formatToSongPath(difficultyName));
			set('weekRaw', PlayState.storyWeek);
			set('week', WeekData.weeksList[PlayState.storyWeek]);
			set('seenCutscene', PlayState.seenCutscene);
			set('boyfriendName', (PlayState.SONG.player1 != null ? PlayState.SONG.player1 : 'bf'));
			set('dadName', (PlayState.SONG.player2 != null ? PlayState.SONG.player2 : 'dad'));
			set('gfName', (PlayState.SONG.gfVersion != null ? PlayState.SONG.gfVersion : 'gf'));
			set('gfVersion', (PlayState.SONG.gfVersion != null ? PlayState.SONG.gfVersion : 'gf'));
		}
		else
		{
			// Fallbacks when SONG not yet available (e.g. menus)
			set('curBpm', Conductor.bpm);
			set('bpm', 100);
			set('scrollSpeed', 1);
			set('crochet', Conductor.crochet);
			set('stepCrochet', Conductor.stepCrochet);
			set('songLength', 0);
			set('songName', '');
			set('songPath', '');
			set('startedCountdown', false);
			set('curStage', 'stage');
			set('isStoryMode', PlayState.isStoryMode);
			set('difficulty', PlayState.storyDifficulty);
			var difficultyName:String = CoolUtil.difficulties[PlayState.storyDifficulty];
			set('difficultyName', difficultyName);
			set('difficultyPath', Paths.formatToSongPath(difficultyName));
			set('weekRaw', PlayState.storyWeek);
			set('week', WeekData.weeksList[PlayState.storyWeek]);
			set('seenCutscene', PlayState.seenCutscene);
			set('boyfriendName', 'bf');
			set('dadName', 'dad');
			set('gfName', 'gf');
			set('gfVersion', 'gf');
		}

		set('cameraX', 0);
		set('cameraY', 0);
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);
		set('curBeat', 0);
		set('curStep', 0);
		set('curDecBeat', 0);
		set('curDecStep', 0);
		set('score', 0);
		set('misses', 0);
		set('hits', 0);
		set('rating', 0);
		set('ratingName', '');
		set('ratingFC', '');
		set('phoenixVersion', MainMenuState.phoenixEngineVersion.trim());
		set('version', MainMenuState.psychEngineVersion.trim());
		set('jsVersion', MainMenuState.psychEngineJSVersion.trim());
		set('inGameOver', false);
		set('mustHitSection', false);
		set('altAnim', false);
		set('gfSection', false);
		if (game != null)
		{
			set('npsSpeedMult', game.npsSpeedMult);
			set('polyphonyOppo', game.polyphonyOppo);
			set('polyphonyBF', game.polyphonyBF);
			set('healthGainMult', game.healthGain);
			set('healthLossMult', game.healthLoss);
			set('playbackRate', game.playbackRate);
			set('instakillOnMiss', game.instakillOnMiss);
			set('botPlay', game.cpuControlled);
			set('practice', game.practiceMode);
			set('defaultBoyfriendX', game.BF_X);
			set('defaultBoyfriendY', game.BF_Y);
			set('defaultOpponentX', game.DAD_X);
			set('defaultOpponentY', game.DAD_Y);
			set('defaultGirlfriendX', game.GF_X);
			set('defaultGirlfriendY', game.GF_Y);
		}
		else
		{
			set('npsSpeedMult', 1);
			set('polyphonyOppo', 0);
			set('polyphonyBF', 0);
			set('healthGainMult', 1);
			set('healthLossMult', 1);
			set('playbackRate', 1);
			set('instakillOnMiss', false);
			set('botPlay', false);
			set('practice', false);
			set('defaultBoyfriendX', 0);
			set('defaultBoyfriendY', 0);
			set('defaultOpponentX', 0);
			set('defaultOpponentY', 0);
			set('defaultGirlfriendX', 0);
			set('defaultGirlfriendY', 0);
		}
		for (i in 0...4)
		{
			set('defaultPlayerStrumX' + i, 0);
			set('defaultPlayerStrumY' + i, 0);
			set('defaultOpponentStrumX' + i, 0);
			set('defaultOpponentStrumY' + i, 0);
		}
		set('downscroll', ClientPrefs.downScroll);
		set('middlescroll', ClientPrefs.middleScroll);
		set('framerate', ClientPrefs.framerate);
		set('ghostTapping', ClientPrefs.ghostTapping);
		set('hideHud', ClientPrefs.hideHud);
		set('timeBarType', ClientPrefs.timeBarType);
		set('scoreZoom', ClientPrefs.scoreZoom);
		set('cameraZoomOnBeat', ClientPrefs.camZooms);
		set('flashingLights', ClientPrefs.flashing);
		set('noteOffset', ClientPrefs.noteOffset);
		set('healthBarAlpha', ClientPrefs.healthBarAlpha);
		set('noResetButton', ClientPrefs.noReset);
		set('lowQuality', ClientPrefs.lowQuality);
		set('shadersEnabled', ClientPrefs.shaders);
		set('scriptName', scriptName);
		set('currentModDirectory', Mods.currentModDirectory);
		set('noteSkin', ClientPrefs.noteSkin);
		try { set('noteSkinPostfix', objects.NoteHelpers.getNoteSkinPostfix()); } catch (e:Dynamic) { set('noteSkinPostfix', ''); }
		set('splashSkin', ClientPrefs.splashType);
		try { set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix()); } catch (e:Dynamic) { set('splashSkinPostfix', ''); }
		set('user_path', CoolSystemStuff.getUserPath());
		set('user_name', CoolSystemStuff.getUsername());
		#if windows
		set('buildTarget', 'windows');
		#elseif linux
		set('buildTarget', 'linux');
		#elseif mac
		set('buildTarget', 'mac');
		#elseif html5
		set('buildTarget', 'browser');
		#elseif android
		set('buildTarget', 'android');
		#else
		set('buildTarget', 'unknown');
		#end

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

		// Script interop — mirrors psychlua.callbacks.ScriptCallbacks for Lua (#87)
		psychlua.pystdlib.PyScriptLib.register(this);

// REFACTOR: extracted to psychlua.pystdlib.PyHardwareLib
	PyHardwareLib.register(this);

		for (name => func in registeredFunctions) {
			if (func != null) {
				_missingCalls.remove(name);
				set(name, func);
			}
		}

		// Bind every registered/custom function into the interpreter, then let
		// other systems add their own callbacks (CustomSubstate, Achievements...).
		registerCustomFunctions();
		CustomSubstate.implementPython(this);
		#if ACHIEVEMENTS_ALLOWED Achievements.addPythonCallbacks(this); #end
		#if DISCORD_ALLOWED DiscordClient.addPythonCallbacks(this); #end
		#if flxanimate FlxAnimateFunctions.implementPython(this); #end

		lastCalledScript = this;
		try
		{
			interp.execute(parser.parseString(code));
		}
		catch (e:Error)
		{
			pyTrace('Error loading python script: "$scriptName"\n' + getErrorString(e), true, false, FlxColor.RED);
			game.pythonArray.remove(this);
			closed = true;
			return;
		}
		catch (e:Dynamic)
		{
			pyTrace('Error loading python script: "$scriptName"\n' + Std.string(e), true, false, FlxColor.RED);
			game.pythonArray.remove(this);
			closed = true;
			return;
		}

		pyTrace('python file loaded succesfully: ' + scriptName, true);

		call('onCreate', []);
	}

	// -------------------------------------------------------------------- //
	//                            INTERNALS                                 //
	// -------------------------------------------------------------------- //

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
			if (closed) stop();
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

	public function set(variable:String, data:Dynamic) {
		if (closed) return;

		_missingCalls.remove(variable);
		if(Reflect.isFunction(data)
			&& ModSecurity.isRuntimeCallbackBlocked(variable, sandboxed, securityAllowlist))
		{
			var rule:String = ModSecurity.runtimeRuleForCallback(variable);
			data = Reflect.makeVarArgs(function(_args:Array<Dynamic>):Dynamic
			{
				throw reportSecurityRuntime('$variable ($rule)');
			});
		}
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

	/** Log a runtime guard failure to both the mod console and process log. */
	public function reportSecurityRuntime(capability:String, ?line:Int = 0):String
	{
		var message:String = ModSecurity.formatRuntimeBlock(securityModName, scriptName, capability, line);
		trace(message);
		if(PlayState.instance != null) PlayState.instance.addTextToDebug(message, FlxColor.RED);
		return message;
	}

	public inline function allowsSecurityRule(rule:String):Bool
		return ModSecurity.isRuleAllowed(rule, securityAllowlist);

	public function allowClassAccess(className:String):Bool
	{
		if(!sandboxed || !ModSecurity.isPrivilegedClass(className) || allowsSecurityRule('engine.native-class')) return true;
		reportSecurityRuntime('privileged class reflection: $className');
		return false;
	}

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

	public function pyTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE) {
		if (ignoreCheck || getVar('pythonDebugMode')) {
			if (deprecated && !getVar('pythonDeprecatedWarnings')) {
				return;
			}
			PlayState.instance.addTextToDebug(text, color);
			trace(text);
		}
	}

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

	// Hython 0.0.352-beta tokenizes `global` as TGlobal, but its Parser does
	// not handle TGlobal in parseStatement(), throwing "Unexpected token: global".
	// Top-level variables declared before `def` are already shared across functions
	// via captured reference boxes, so replacing `global ...` lines with `pass`
	// preserves line numbers and indentation without crashing the parser.
	static function preprocessHythonCode(code:String):String {
		var lines:Array<String> = code.split("\n");
		for (i in 0...lines.length) {
			var line:String = lines[i];
			var trimmed:String = line.ltrim();
			if (trimmed.startsWith("global ") || trimmed.startsWith("global\t")) {
				var indent:String = line.substr(0, line.length - trimmed.length);
				lines[i] = indent + "pass";
			}
		}
		return lines.join("\n");
	}

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

	public static function registerFunction(name:String, func:Dynamic):Void
		registeredFunctions.set(name, func);

	public static function isOfTypes(value:Any, types:Array<Dynamic>) {
		for (type in types) {
			if (Std.isOfType(value, type)) return true;
		}
		return false;
	}

	function registerCustomFunctions() {
		for (name => func in customFunctions) {
			if (func != null) {
				_missingCalls.remove(name);
				set(name, func);
			}
		}
	}

	function addLocalCallback(name:String, myFunction:Dynamic) {
		_missingCalls.remove(name);
		set(name, myFunction);
	}

	// -------------------------------------------------------------------- //
	//                          HELPERS                                     //
	// -------------------------------------------------------------------- //

	function getInstance():Dynamic {
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}

	inline function getTextObject(name:String):FlxText {
		return PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : Reflect.getProperty(PlayState.instance, name);
	}

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

	function cancelTween(tag:String) {
		if(PlayState.instance.modchartTweens.exists(tag)) {
			PlayState.instance.modchartTweens.get(tag).cancel();
			PlayState.instance.modchartTweens.get(tag).destroy();
			PlayState.instance.modchartTweens.remove(tag);
		}
	}

	function tweenPrepare(tag:String, vars:String) {
		if (tag != null) cancelTween(tag);
		var variables:Array<String> = vars.split('.');
		var sexyProp:Dynamic = FunkinLua.getObjectDirectly(variables[0]);
		if(variables.length > 1)
			sexyProp = FunkinLua.getVarInArray(FunkinLua.getPropertyLoopThingWhatever(variables), variables[variables.length-1]);

		return sexyProp;
	}

	function cancelTimer(tag:String) {
		if(PlayState.instance.modchartTimers.exists(tag)) {
			PlayState.instance.modchartTimers.get(tag).cancel();
			PlayState.instance.modchartTimers.remove(tag);
		}
	}

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

	public static inline function getInstanceStatic()
	{
		return PlayState.instance.isDead ? GameOverSubstate.instance : PlayState.instance;
	}
}
#end
