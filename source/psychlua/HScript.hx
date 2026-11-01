package psychlua;

#if HSCRIPT_ALLOWED
import hscript.Parser;
import hscript.Interp;
import hscript.Expr;
#end

import haxe.Exception;
import backend.Paths;
import backend.Conductor;
import backend.ClientPrefs;
import backend.CoolUtil;
import backend.ModSecurity;
import backend.Native;
import backend.ScriptSecurityScanner;
import backend.ScriptSecurityScanner.ScriptSecurityFinding;
import backend.WeekData;
import objects.Character;
import objects.Alphabet;
import objects.NoteHelpers;
import objects.NoteSplash;
import play.PlayState;
import states.MainMenuState;
import utils.CoolSystemStuff;

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
 * Haxe/HScript host (CodenameCrew `hscript-improved`), in two flavours:
 *
 * - **Embedded** — one interpreter lazily created per Lua script so Lua mods can
 *   escape into Haxe through `runHaxeCode` / `runHaxeFunction` /
 *   `addHaxeLibrary` (see `implement()`). `parentLua` is the owning script.
 * - **Standalone** — a first-class mod script loaded straight from a `.hx` or
 *   `.hscript` file, with no Lua parent. It mirrors `FunkinLua` /
 *   `PythonScript`: the engine discovers it in the usual script folders,
 *   registers it in `PlayState.hscriptArray`, runs its top-level code, then
 *   dispatches the same lifecycle hooks (`onCreate`, `onBeatHit`, ...) and
 *   control-flow sentinels (`Function_Stop`, ...).
 *
 * Each instance owns its own `Interp`, so top-level variables and functions are
 * private to that script. Scripts share state explicitly through `game`
 * (the `PlayState`), `PlayState.instance.variables` (`setVar`/`getVar`) or the
 * inter-script calls seeded by `seedScriptApi()`.
 *
 * Not to be confused with `psychlua.HaxeScript`, the separate host for
 * `data/states/<Name>.hx` scripted states/substates (`psychlua.StateScripts`).
 */
class HScript
{
	// Sentinel values are intentionally the SAME strings as FunkinLua's so the
	// existing `ret != FunkinLua.Function_Stop` checks keep working for HScript.
	public static var Function_Stop:Dynamic = "##PSYCHLUA_FUNCTIONSTOP";
	public static var Function_Continue:Dynamic = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static var Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";
	public static var Function_StopAll:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";

	public static var parser:Parser = new Parser();
	public var interp:Interp;
	var _parsedCache:Map<String, Expr> = new Map();
	var _missingCalls:Map<String, Bool> = new Map();

	public var variables(get, never):Map<String, Dynamic>;

	#if LUA_ALLOWED
	/** Owning Lua script in embedded mode; always `null` for standalone mods. */
	public var parentLua:FunkinLua;
	#end

	/** Resolved file path for standalone scripts; the Lua parent's path when embedded. */
	public var scriptName:String = '';
	public var modFolder:String = null;
	public var closed:Bool = false;
	/** `true` when this interpreter was loaded from its own `.hx`/`.hscript` file. */
	public var standalone:Bool = false;
	public var lastCalledFunction:String = '';
	public static var lastCalledScript:HScript = null;

	/** Runtime half of the softmod sandbox; standalone scripts only (embedded mode delegates to the Lua parent). */
	public var sandboxed:Bool = false;
	public var securityModName:String = null;
	public var securityAllowlist:Array<String> = [];

	public static var customFunctions:Map<String, Dynamic> = [];
	public static var registeredFunctions:Map<String, Dynamic> = [];

	public function get_variables()
	{
		return interp != null ? interp.variables : null;
	}

	/** Whether `file` names a standalone HScript mod file (extension check is case-insensitive). */
	public static function isHScriptFile(file:String):Bool
	{
		if(file == null) return false;
		var lower:String = file.toLowerCase();
		return lower.endsWith('.hx') || lower.endsWith('.hscript');
	}

	/**
	 * Logical script name used to deduplicate discovery: `scripts/hud.hx` and
	 * `scripts/hud.hscript` are the same script, so a higher-priority folder
	 * (or a `.hx` in the same folder) shadows the other spelling.
	 */
	public static function scriptBaseName(file:String):String
	{
		if(file == null) return '';
		var lower:String = file.toLowerCase();
		if(lower.endsWith('.hscript')) return file.substr(0, file.length - '.hscript'.length);
		if(lower.endsWith('.hx')) return file.substr(0, file.length - '.hx'.length);
		return file;
	}

	public static function registerFunction(name:String, func:Dynamic):Void
		registeredFunctions.set(name, func);

	/**
	 * Load a standalone script from `scriptName` (a resolved path, or a
	 * `Paths`-relative key) without any Lua parent.
	 */
	public static function fromFile(scriptName:String, ?scriptCode:String):HScript
		return new HScript(null, scriptName, scriptCode);

	/**
	 * @param parent owning Lua script for embedded mode, or `null` together with
	 * `scriptName` to load a standalone `.hx`/`.hscript` mod file.
	 */
	public function new(parent:#if LUA_ALLOWED FunkinLua #else Dynamic #end, ?scriptName:String, ?scriptCode:String)
	{
		#if HSCRIPT_ALLOWED
		#if LUA_ALLOWED
		parentLua = parent;
		#end
		standalone = (scriptName != null);
		if(standalone)
		{
			loadStandalone(scriptName, scriptCode);
		}
		else
		{
			#if LUA_ALLOWED
			this.scriptName = (parent != null ? parent.scriptName : '');
			this.modFolder = (parent != null ? parent.modFolder : null);
			#end
			interp = new Interp();
			seedScope();
		}
		#end
	}

	#if LUA_ALLOWED
	public static function initHaxeModule(parent:FunkinLua)
	{
		#if HSCRIPT_ALLOWED
		if(parent.hscript == null)
		{
			trace('initializing haxe interp for: ${parent.scriptName}');
			parent.hscript = new HScript(parent);
		}
		#end
	}
	#end

	// -------------------------------------------------------------------- //
	//                        STANDALONE LOADING                            //
	// -------------------------------------------------------------------- //

	#if HSCRIPT_ALLOWED
	function loadStandalone(scriptName:String, ?scriptCode:String)
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
		// seeding the scope, or running any top-level Haxe statement.
		var security = ModSecurity.checkScript(scriptName, code, 'haxe');
		sandboxed = security.sandboxed;
		securityModName = security.modName;
		securityAllowlist = security.allowlist;
		modFolder = security.modFolder;
		ModSecurity.report(security, function(message:String) {
			if(game != null) game.addTextToDebug(message, FlxColor.RED);
		});
		if(security.findings.length > 0)
		{
			closed = true;
			return;
		}
		if(code == null)
		{
			closed = true;
			hxTrace('Error loading hscript: "$scriptName"\nSource file could not be read.', true, false, FlxColor.RED);
			return;
		}

		interp = new Interp();
		// `public var`/`static var` at the top level keep their own buckets so
		// the host (and `get()`) can tell shared state from private state.
		interp.allowPublicVariables = true;
		interp.allowStaticVariables = true;
		// `import a.b.Class;` resolves host classes at runtime; sandboxed mods
		// keep the seeded scope only, mirroring PythonScript's allowClassResolve.
		interp.importEnabled = !sandboxed || allowsSecurityRule('engine.native-class');

		if(game != null) game.hscriptArray.push(this);

		seedScope();
		seedInitialGlobals();

		for (name => func in registeredFunctions)
		{
			if(func != null) set(name, func);
		}
		seedScriptApi();
		CustomSubstate.implementHScript(this);
		for (name => func in customFunctions)
		{
			if(func != null) set(name, func);
		}

		code = code.split("\r\n").join("\n");
		code = preprocessHScriptCode(code);

		lastCalledScript = this;
		try
		{
			var fileParser:Parser = new Parser();
			fileParser.line = 1;
			fileParser.allowTypes = true;
			fileParser.allowMetadata = true;
			var expr:Expr = fileParser.parseString(code, scriptName);
			interp.execute(expr);
		}
		catch (e:Dynamic)
		{
			hxTrace('Error loading hscript: "$scriptName"\n' + Std.string(e), true, false, FlxColor.RED);
			if(game != null) game.hscriptArray.remove(this);
			closed = true;
			return;
		}

		hxTrace('hscript file loaded succesfully: ' + scriptName, true);

		call('onCreate', []);
	}

	/**
	 * Line-preserving cleanup so a plain `.hx` file can be a mod script as-is:
	 * `hscript-improved` parses `import` natively (handled by the interpreter)
	 * but only accepts `package` declarations in module mode, so the package
	 * line is commented out. Error line numbers therefore stay identical to
	 * the file on disk.
	 */
	static function preprocessHScriptCode(code:String):String
	{
		var lines:Array<String> = code.split("\n");
		for (i in 0...lines.length)
		{
			var trimmed:String = lines[i].ltrim();
			if(trimmed.startsWith("package ") || trimmed.startsWith("package;") || trimmed.startsWith("package\t"))
				lines[i] = "//" + lines[i];
		}
		return lines.join("\n");
	}

	/**
	 * Flat engine-state globals mirroring FunkinLua/PythonScript so a script's
	 * `onCreate` sees the same starting context in every language. The live
	 * values are kept current by `PlayState.setOnScripts()`; HScript scripts
	 * can always read the authoritative state through `game` instead.
	 * Do not redeclare these with `var` at the top level: engine writes go to
	 * the script's global scope, and a local `var curBeat` would shadow them.
	 */
	function seedInitialGlobals()
	{
		final game:PlayState = PlayState.instance;

		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('Function_StopLua', Function_StopLua);
		set('Function_StopAll', Function_StopAll);
		set('hscriptDebugMode', false);
		set('hscriptDeprecatedWarnings', true);
		set('inChartEditor', false);
		set('modFolder', modFolder);
		set('scriptName', scriptName);
		set('currentModDirectory', Mods.currentModDirectory);

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
			set('boyfriendName', (PlayState.SONG.player1 != null ? PlayState.SONG.player1 : 'bf'));
			set('dadName', (PlayState.SONG.player2 != null ? PlayState.SONG.player2 : 'dad'));
			set('gfName', (PlayState.SONG.gfVersion != null ? PlayState.SONG.gfVersion : 'gf'));
			set('gfVersion', (PlayState.SONG.gfVersion != null ? PlayState.SONG.gfVersion : 'gf'));
		}
		else
		{
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
			set('boyfriendName', 'bf');
			set('dadName', 'dad');
			set('gfName', 'gf');
			set('gfVersion', 'gf');
		}

		set('isStoryMode', PlayState.isStoryMode);
		set('difficulty', PlayState.storyDifficulty);
		var difficultyName:String = CoolUtil.difficulties[PlayState.storyDifficulty];
		set('difficultyName', difficultyName);
		set('difficultyPath', Paths.formatToSongPath(difficultyName));
		set('weekRaw', PlayState.storyWeek);
		set('week', WeekData.weeksList[PlayState.storyWeek]);
		set('seenCutscene', PlayState.seenCutscene);

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
		set('noteSkin', ClientPrefs.noteSkin);
		try { set('noteSkinPostfix', NoteHelpers.getNoteSkinPostfix()); } catch (e:Dynamic) { set('noteSkinPostfix', ''); }
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
	}

	/** Inter-script API seeded only for standalone scripts (mirrors ScriptCallbacks/PyScriptLib). */
	function seedScriptApi()
	{
		// Load another standalone .hx/.hscript at runtime; extension optional.
		set('addHScript', function(hxFile:String, ?ignoreAlreadyRunning:Bool = false):Bool
		{
			if(hxFile == null || PlayState.instance == null) return false;
			return PlayState.instance.startHScriptOnFolder(hxFile);
		});

		set('removeHScript', function(hxFile:String):Bool
		{
			if(hxFile == null || PlayState.instance == null) return false;
			return PlayState.instance.removeHScript(hxFile);
		});

		// Generic loader: dispatches on extension (.lua/.py/.hx/.hscript,
		// or tries each in that order when no extension is given).
		set('addScript', function(file:String, ?ignoreAlreadyRunning:Bool = false):Bool
		{
			if(file == null || PlayState.instance == null) return false;
			if(isHScriptFile(file)) return PlayState.instance.startHScriptOnFolder(file);
			#if LUA_ALLOWED
			if(file.endsWith('.lua')) return PlayState.instance.startLuasOnFolder(file);
			#end
			#if PYTHON_ALLOWED
			if(file.endsWith('.py')) return PlayState.instance.startPythonScriptOnFolder(file);
			#end
			#if LUA_ALLOWED
			if(PlayState.instance.startLuasOnFolder(file + '.lua')) return true;
			#end
			#if PYTHON_ALLOWED
			if(PlayState.instance.startPythonScriptOnFolder(file + '.py')) return true;
			#end
			return PlayState.instance.startHScriptOnFolder(file);
		});

		set('getRunningScripts', function():Array<String>
		{
			return getRunningScriptNames();
		});

		set('isRunning', function(file:String):Bool
		{
			if(file == null || PlayState.instance == null) return false;
			var wantedFull:String = scriptBaseName(file);
			var wantedBase:String = wantedFull.split('/').pop().split('\\').pop();
			for (name in getRunningScriptNames())
			{
				var runningFull:String = scriptBaseName(name);
				var runningBase:String = runningFull.split('/').pop().split('\\').pop();
				if(runningFull == wantedFull || runningBase == wantedBase) return true;
			}
			return false;
		});

		// Broadcast a hook to every other script (all languages), like
		// PlayState.callOnScripts but excluding the caller by default.
		set('callOnScripts', function(funcName:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ignoreSelf:Bool = true):Dynamic
		{
			if(funcName == null || PlayState.instance == null) return null;
			if(args == null) args = [];
			var exclusions:Array<String> = (ignoreSelf && scriptName != null) ? [scriptName] : [];
			return PlayState.instance.callOnScripts(funcName, args, ignoreStops, exclusions);
		});
	}

	function getRunningScriptNames():Array<String>
	{
		var names:Array<String> = [];
		if(PlayState.instance == null) return names;
		#if LUA_ALLOWED
		for (script in PlayState.instance.luaArray) names.push(script.scriptName);
		#end
		#if PYTHON_ALLOWED
		for (script in PlayState.instance.pythonArray) names.push(script.scriptName);
		#end
		for (script in PlayState.instance.hscriptArray) names.push(script.scriptName);
		return names;
	}
	#end

	// -------------------------------------------------------------------- //
	//                              SCOPE                                   //
	// -------------------------------------------------------------------- //

	/**
	 * Seed the interpreter scope shared by embedded and standalone scripts:
	 * engine/Flixel classes by name, hardware helpers, shared `PlayState`
	 * variables, `debugPrint`, `addHaxeLibrary` and the callback factories.
	 * Anything not seeded can be pulled in by the script itself with a native
	 * `import a.b.Class;` (standalone, unsandboxed) or `addHaxeLibrary()`.
	 */
	function seedScope()
	{
		#if HSCRIPT_ALLOWED
		interp.variables.set('FlxG', flixel.FlxG);
		interp.variables.set('FlxSprite', flixel.FlxSprite);
		interp.variables.set('FlxCamera', flixel.FlxCamera);
		interp.variables.set('FlxTimer', flixel.util.FlxTimer);
		interp.variables.set('FlxTween', flixel.tweens.FlxTween);
		interp.variables.set('FlxEase', flixel.tweens.FlxEase);
		interp.variables.set('FlxMath', flixel.math.FlxMath);
		interp.variables.set('PlayState', PlayState);
		interp.variables.set('game', PlayState.instance);
		interp.variables.set('Paths', Paths);
		interp.variables.set('Conductor', Conductor);
		interp.variables.set('ClientPrefs', ClientPrefs);
		interp.variables.set('Character', Character);
		interp.variables.set('Alphabet', Alphabet);
		interp.variables.set('CustomSubstate', psychlua.CustomSubstate);
		#if ACHIEVEMENTS_ALLOWED
		interp.variables.set('Achievements', Achievements);
		#end
		#if DISCORD_ALLOWED
		interp.variables.set('DiscordClient', DiscordClient);
		#end
		interp.variables.set('ModState', states.ModState);
		interp.variables.set('ModSubState', states.substates.ModSubState);
		interp.variables.set('StateScripts', psychlua.StateScripts);
		interp.variables.set('switchCustomState', psychlua.StateScripts.switchState);
		interp.variables.set('openModSubState', psychlua.StateScripts.openSubState);
		#if (sys)
		interp.variables.set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		#end
		interp.variables.set('ShaderFilter', openfl.filters.ShaderFilter);
		interp.variables.set('StringTools', StringTools);
		interp.variables.set('Math', Math);
		interp.variables.set('Std', Std);
		// FlxColor is an abstract, so it has no runtime class to hand out:
		// seed a shim object exposing the preset constants and constructors.
		// The underlying value is an Int, exactly like the abstract itself.
		interp.variables.set('FlxColor', {
			TRANSPARENT: FlxColor.TRANSPARENT,
			WHITE: FlxColor.WHITE,
			GRAY: FlxColor.GRAY,
			BLACK: FlxColor.BLACK,
			GREEN: FlxColor.GREEN,
			BLUE: FlxColor.BLUE,
			RED: FlxColor.RED,
			YELLOW: FlxColor.YELLOW,
			CYAN: FlxColor.CYAN,
			LIME: FlxColor.LIME,
			ORANGE: FlxColor.ORANGE,
			fromRGB: function(r:Int, g:Int, b:Int, a:Int = 255):FlxColor return FlxColor.fromRGB(r, g, b, a),
			fromInt: function(value:Int):FlxColor return FlxColor.fromInt(value),
			fromString: function(value:String):FlxColor return FlxColor.fromString(value),
			fromHSB: function(hue:Float, saturation:Float, brightness:Float, alpha:Float = 1):FlxColor return FlxColor.fromHSB(hue, saturation, brightness, alpha),
			fromHSL: function(hue:Float, saturation:Float, lightness:Float, alpha:Float = 1):FlxColor return FlxColor.fromHSL(hue, saturation, lightness, alpha)
		});
		// Reflection escape hatches; withheld from sandboxed mods, which must
		// stick to the seeded scope (the source scanner blocks them anyway).
		if(!effectiveSandboxed())
		{
			interp.variables.set('Type', Type);
			interp.variables.set('Reflect', Reflect);
		}
		// Hardware information (GPU, driver, CPU, OS), mirroring the Lua API.
		interp.variables.set('Native', Native);
		interp.variables.set('getSystemInfo', function():String {
			return Native.buildSystemInfo();
		});
		interp.variables.set('getGPUName', function():String {
			return Native.getGPUName();
		});
		interp.variables.set('getGPUVendor', function():String {
			return Native.getGPUVendor();
		});
		interp.variables.set('getGPUDriverVersion', function():String {
			return Native.getGPUDriverVersion();
		});
		interp.variables.set('getCPUName', function():String {
			return Native.getCPUName();
		});
		interp.variables.set('getCPUVendor', function():String {
			return Native.getCPUVendor();
		});
		interp.variables.set('getOSName', function():String {
			return Native.getOSName();
		});
		interp.variables.set('getOSVersion', function():String {
			return Native.getOSVersion();
		});
		interp.variables.set('getGraphicsApi', function():String {
			return Native.getGraphicsApi();
		});
		interp.variables.set('getAudioApi', function():String {
			return Native.getSystemInfo().audioApi;
		});

		// Shared state with every other script language (PlayState.variables).
		interp.variables.set('setVar', function(name:String, value:Dynamic)
		{
			if(PlayState.instance != null) PlayState.instance.variables.set(name, value);
		});
		interp.variables.set('getVar', function(name:String)
		{
			var result:Dynamic = null;
			if(PlayState.instance != null && PlayState.instance.variables.exists(name)) result = PlayState.instance.variables.get(name);
			return result;
		});
		interp.variables.set('removeVar', function(name:String)
		{
			if(PlayState.instance != null && PlayState.instance.variables.exists(name))
			{
				PlayState.instance.variables.remove(name);
				return true;
			}
			return false;
		});
		interp.variables.set('debugPrint', function(text:String, ?color:FlxColor = null) {
			if(color == null) color = FlxColor.WHITE;
			hxTrace(text, true, false, color);
		});

		// Publish a callback into every currently-running script (all
		// languages) and into each host's custom-functions table so scripts
		// created afterwards get it too.
		interp.variables.set('createGlobalCallback', function(name:String, func:Dynamic)
		{
			if(PlayState.instance != null)
			{
				#if LUA_ALLOWED
				for (script in PlayState.instance.luaArray)
					if(script != null && script.lua != null && !script.closed)
						Convert.addCallback(script.lua, name, func);
				#end
				#if PYTHON_ALLOWED
				for (script in PlayState.instance.pythonArray)
					if(script != null && !script.closed)
						script.set(name, func);
				#end
				for (script in PlayState.instance.hscriptArray)
					if(script != null && !script.closed)
						script.set(name, func);
			}
			#if LUA_ALLOWED
			FunkinLua.customFunctions.set(name, func);
			#end
			#if PYTHON_ALLOWED
			PythonScript.customFunctions.set(name, func);
			#end
			HScript.customFunctions.set(name, func);
		});

		// Embedded mode: a local Lua callback on the parent script (legacy).
		// Standalone mode: a plain function in this script's own scope.
		interp.variables.set('createCallback', function(name:String, func:Dynamic, ?funk:#if LUA_ALLOWED FunkinLua #else Dynamic #end = null)
		{
			#if LUA_ALLOWED
			if(funk == null) funk = parentLua;
			if(funk != null)
			{
				funk.addLocalCallback(name, func);
				return;
			}
			#end
			addLocalCallback(name, func);
		});

		interp.variables.set('addHaxeLibrary', function(libName:String, ?libPackage:String = '') {
			try {
				addLibrary(libName, libPackage);
			}
			catch (e:Dynamic) {
				hxTrace(scriptName + ":" + lastCalledFunction + " - " + e, false, false, FlxColor.RED);
			}
		});
		#if LUA_ALLOWED
		interp.variables.set('parentLua', parentLua);
		#else
		interp.variables.set('parentLua', null);
		#end
		#end
	}

	/**
	 * Bring a host class into this script's scope under its short name.
	 * Returns whether a class was resolved; sandboxed scripts are refused
	 * privileged classes (see `backend.ModSecurity`).
	 */
	public function addLibrary(libName:String, ?libPackage:String = ''):Bool
	{
		#if HSCRIPT_ALLOWED
		if(interp == null || libName == null) return false;
		var str:String = '';
		if(libPackage != null && libPackage.length > 0)
			str = libPackage + '.';
		if(!allowClassAccess(str + libName)) return false;

		var resolved:Class<Dynamic> = Type.resolveClass(str + libName); // REFACTOR: legacy bare-name fallback
		if (resolved == null) resolved = LuaUtils.resolveClassCompat(libName);
		interp.variables.set(libName, resolved);
		_missingCalls.remove(libName);
		return resolved != null;
		#else
		return false;
		#end
	}

	// -------------------------------------------------------------------- //
	//                          SCRIPT INTERFACE                            //
	// -------------------------------------------------------------------- //

	/** Call a function defined by the script (engine hooks land here). */
	public function call(func:String, args:Array<Dynamic>):Dynamic
	{
		if(closed || interp == null) return Function_Continue;
		if(args == null) args = [];

		lastCalledFunction = func;
		lastCalledScript = this;

		if(_missingCalls.exists(func)) return Function_Continue;

		var fn:Dynamic = resolveScriptVar(func);
		if(fn == null || !Reflect.isFunction(fn))
		{
			_missingCalls.set(func, true);
			return Function_Continue;
		}

		try
		{
			var result:Dynamic = Reflect.callMethod(null, fn, args);
			if(result == null) result = Function_Continue;
			if(closed) stop();
			return result;
		}
		catch (e:Dynamic)
		{
			hxTrace(scriptName + ": ERROR (" + func + "): " + Std.string(e), false, false, FlxColor.RED);
			// A hook that throws once would throw every frame; disable just
			// that hook for this script (mirrors PythonScript).
			_missingCalls.set(func, true);
			return Function_Continue;
		}
	}

	/** Write a global into the script's scope (engine state, callbacks, ...). */
	public function set(variable:String, data:Dynamic)
	{
		if(closed || interp == null) return;

		_missingCalls.remove(variable);
		if(standalone && Reflect.isFunction(data)
			&& ModSecurity.isRuntimeCallbackBlocked(variable, sandboxed, securityAllowlist))
		{
			var rule:String = ModSecurity.runtimeRuleForCallback(variable);
			data = Reflect.makeVarArgs(function(_args:Array<Dynamic>):Dynamic
			{
				throw reportSecurityRuntime('$variable ($rule)');
			});
		}
		interp.setVar(variable, data);
		// A top-level `var` also lives in the captured locals its functions
		// read; keep that reference in sync so host writes are visible.
		var localRef = interp.locals.get(variable);
		if(localRef != null) localRef.r = data;
	}

	/** Read a global back out of the script's scope, or `null` when unset. */
	public function get(variable:String):Dynamic
	{
		if(closed || interp == null) return null;
		var localRef = interp.locals.get(variable);
		if(localRef != null) return localRef.r;
		return resolveScriptVar(variable);
	}

	public function addLocalCallback(name:String, myFunction:Dynamic)
	{
		_missingCalls.remove(name);
		set(name, myFunction);
	}

	public function stop()
	{
		closed = true;
		interp = null;
		_parsedCache.clear();
		_missingCalls.clear();
	}

	function resolveScriptVar(name:String):Dynamic
	{
		if(interp == null) return null;
		if(interp.variables.exists(name)) return interp.variables.get(name);
		if(interp.publicVariables.exists(name)) return interp.publicVariables.get(name);
		if(interp.staticVariables.exists(name)) return interp.staticVariables.get(name);
		return null;
	}

	function getBoolVar(variable:String):Bool
	{
		var value:Dynamic = get(variable);
		return value == true;
	}

	/**
	 * Script-visible logging. Embedded mode forwards to the Lua parent's
	 * trace channel ( honouring `luaDebugMode` there); standalone mode writes
	 * to the PlayState debug text, gated by `hscriptDebugMode` exactly like
	 * `luaTrace`/`pyTrace`.
	 */
	public function hxTrace(text:String, ignoreCheck:Bool = false, deprecated:Bool = false, color:FlxColor = FlxColor.WHITE)
	{
		#if LUA_ALLOWED
		if(parentLua != null && parentLua.lua != null)
		{
			LuaUtils.luaTrace(parentLua.lua, text, ignoreCheck, deprecated, color);
			return;
		}
		#end
		if(ignoreCheck || getBoolVar('hscriptDebugMode'))
		{
			if(deprecated && !getBoolVar('hscriptDeprecatedWarnings')) return;
			if(PlayState.instance != null) PlayState.instance.addTextToDebug(text, color);
			trace(text);
		}
	}

	// -------------------------------------------------------------------- //
	//                              SECURITY                                //
	// -------------------------------------------------------------------- //

	function effectiveSandboxed():Bool
	{
		#if LUA_ALLOWED
		if(parentLua != null) return parentLua.sandboxed;
		#end
		return sandboxed;
	}

	function effectiveAllowlist():Array<String>
	{
		#if LUA_ALLOWED
		if(parentLua != null) return parentLua.securityAllowlist;
		#end
		return securityAllowlist;
	}

	public function allowsSecurityRule(rule:String):Bool
	{
		#if LUA_ALLOWED
		if(parentLua != null) return parentLua.allowsSecurityRule(rule);
		#end
		return ModSecurity.isRuleAllowed(rule, securityAllowlist);
	}

	public function allowClassAccess(className:String):Bool
	{
		#if LUA_ALLOWED
		if(parentLua != null) return parentLua.allowClassAccess(className);
		#end
		if(!sandboxed || !ModSecurity.isPrivilegedClass(className) || allowsSecurityRule('engine.native-class')) return true;
		reportSecurityRuntime('privileged class reflection: $className');
		return false;
	}

	/** Log a runtime guard failure to both the mod console and process log. */
	public function reportSecurityRuntime(capability:String, ?line:Int = 0):String
	{
		#if LUA_ALLOWED
		if(parentLua != null) return parentLua.reportSecurityRuntime(capability, line);
		#end
		var message:String = ModSecurity.formatRuntimeBlock(securityModName, scriptName, capability, line);
		trace(message);
		if(PlayState.instance != null) PlayState.instance.addTextToDebug(message, FlxColor.RED);
		return message;
	}

	public function reportSecurityFinding(context:String, finding:ScriptSecurityFinding):Void
	{
		#if LUA_ALLOWED
		if(parentLua != null)
		{
			parentLua.reportSecurityFinding(context, finding);
			return;
		}
		#end
		reportSecurityRuntime('$context (${finding.rule}) at embedded line ${finding.line}: ${finding.description} | ${finding.snippet}');
	}

	// -------------------------------------------------------------------- //
	//                     RUNNING AD-HOC HAXE SOURCE                       //
	// -------------------------------------------------------------------- //

	#if HSCRIPT_ALLOWED
	public function execute(codeToRun:String, ?funcToRun:String = null, ?funcArgs:Array<Dynamic>):Dynamic
	{
		if(interp == null) return null;
		if(effectiveSandboxed())
		{
			var findings = ScriptSecurityScanner.scan(codeToRun, 'haxe', effectiveAllowlist());
			if(findings.length > 0)
			{
				for(finding in findings) reportSecurityFinding('embedded HScript blocked', finding);
				return null;
			}
		}
		try {
			var expr:Expr;
			if (_parsedCache.exists(codeToRun))
				expr = _parsedCache.get(codeToRun);
			else
			{
				@:privateAccess
				parser.line = 1;
				parser.allowTypes = true;
				expr = parser.parseString(codeToRun, scriptName);
				_parsedCache.set(codeToRun, expr);
			}

			var value:Dynamic = interp.execute(expr);
			return (funcToRun != null) ? executeFunction(funcToRun, funcArgs) : value;
		}
		catch(e:Dynamic)
		{
			hxTrace(scriptName + ":" + lastCalledFunction + " - " + Std.string(e), false, false, FlxColor.RED);
			return null;
		}
	}

	public function executeFunction(funcToRun:String = null, funcArgs:Array<Dynamic>)
	{
		if(funcToRun != null && interp != null)
		{
			var fn:Dynamic = resolveScriptVar(funcToRun);
			if(fn != null && Reflect.isFunction(fn))
			{
				if(funcArgs == null) funcArgs = [];
				try {
					return Reflect.callMethod(null, fn, funcArgs);
				}
				catch(e:Dynamic) hxTrace(scriptName + ":" + lastCalledFunction + " - " + Std.string(e), false, false, FlxColor.RED);
			}
		}
		return null;
	}
	#end

	// -------------------------------------------------------------------- //
	//                            LUA BRIDGE                                //
	// -------------------------------------------------------------------- //

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		funk.addLocalCallback("runHaxeCode", function(codeToRun:String, ?varsToBring:Any = null, ?funcToRun:String = null, ?funcArgs:Array<Dynamic> = null) {
			var retVal:Dynamic = null;
			final types:Array<Dynamic> = [Bool, Int, Float, String, Array];
			#if HSCRIPT_ALLOWED
			initHaxeModule(funk);
			try {
				if(varsToBring != null)
				{
					for (key in Reflect.fields(varsToBring))
					{
						funk.hscript.interp.variables.set(key, Reflect.field(varsToBring, key));
					}
				}
				retVal = funk.hscript.execute(codeToRun, funcToRun, funcArgs);
			}
			catch (e:Dynamic) {
				LuaUtils.luaTrace(funk.lua, funk.scriptName + ":" + funk.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
			}
			#else
			LuaUtils.luaTrace(funk.lua, "runHaxeCode: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end

			if(retVal != null && !LuaUtils.isOfTypes(retVal, types)) retVal = null;
			return retVal;
		});

		funk.addLocalCallback("runHaxeFunction", function(funcToRun:String, ?funcArgs:Array<Dynamic> = null) {
			#if HSCRIPT_ALLOWED
			try {
				return funk.hscript.executeFunction(funcToRun, funcArgs);
			}
			catch(e:Exception)
			{
				LuaUtils.luaTrace(funk.lua, Std.string(e));
				return null;
			}
			#else
			LuaUtils.luaTrace(funk.lua, "runHaxeFunction: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end
		});

		funk.addLocalCallback("addHaxeLibrary", function(libName:String, ?libPackage:String = '') {
			#if HSCRIPT_ALLOWED
			initHaxeModule(funk);
			try {
				funk.hscript.addLibrary(libName, libPackage);
			}
			catch (e:Dynamic) {
				LuaUtils.luaTrace(funk.lua, funk.scriptName + ":" + funk.lastCalledFunction + " - " + e, false, false, FlxColor.RED);
			}
			#else
			LuaUtils.luaTrace(funk.lua, "addHaxeLibrary: HScript isn't supported on this platform!", false, false, FlxColor.RED);
			#end
		});
	}
	#end
}
