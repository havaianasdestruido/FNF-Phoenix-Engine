package psychlua;

import Type.ValueType;
import flixel.FlxBasic;
import flixel.addons.effects.FlxTrail;
import flixel.input.keyboard.FlxKey;
import flixel.system.FlxAssets.FlxShader;
import openfl.Lib;
import openfl.display.BitmapData;
import openfl.display.BlendMode;
import backend.Paths;
import backend.ClientPrefs;
import backend.WeekData;
import backend.ModSecurity;
import backend.LuaDiagnostics;
import backend.ScriptSecurityScanner.ScriptSecurityFinding;
import play.PlayState;
import states.MainMenuState;
import objects.NoteSplash;
import psychlua.callbacks.CameraCallbacks;
import psychlua.callbacks.ModchartCallbacks;
import psychlua.callbacks.DeprecatedCallbacks;
import psychlua.callbacks.EffectCallbacks;
import psychlua.callbacks.FileCallbacks;
import psychlua.callbacks.GameCallbacks;
import psychlua.callbacks.HardwareCallbacks;
import psychlua.callbacks.InputCallbacks;
import psychlua.callbacks.MetaHorrorCallbacks;
import psychlua.callbacks.MiscCallbacks;
import psychlua.callbacks.PropertyCallbacks;
import psychlua.callbacks.SaveDataCallbacks;
import psychlua.callbacks.ScriptCallbacks;
import psychlua.callbacks.ShaderCallbacks;
import psychlua.callbacks.SoundCallbacks;
import psychlua.callbacks.SpriteCallbacks;
import psychlua.callbacks.TextCallbacks;
import psychlua.callbacks.TweenCallbacks;
import psychlua.callbacks.WindowCallbacks;

import backend.Conductor;
import backend.CoolUtil;
import data.Song;
import objects.Character;
import objects.Note;
import headers.Objects;

#if SHADERS_ALLOWED
import flixel.addons.display.FlxRuntimeShader;
import openfl.filters.BitmapFilter;
import openfl.filters.ShaderFilter;
import shaders.ErrorHandledShader;
#end

#if DISCORD_ALLOWED
import backend.DiscordClient;
#end

#if ACHIEVEMENTS_ALLOWED
import backend.Achievements;
#end

typedef LuaTweenOptions = {
	type:FlxTweenType,
	startDelay:Float,
	onUpdate:Null<String>,
	onStart:Null<String>,
	onComplete:Null<String>,
	loopDelay:Float,
	ease:EaseFunction
}

class FunkinLua {
	public static var Function_Stop:Dynamic = "##PSYCHLUA_FUNCTIONSTOP";
	public static var Function_Continue:Dynamic = "##PSYCHLUA_FUNCTIONCONTINUE";
	public static var Function_StopLua:Dynamic = "##PSYCHLUA_FUNCTIONSTOPLUA";

	#if (MODS_ALLOWED && SHADERS_ALLOWED)
	private static var storedFilters:Map<String, ShaderFilter> = []; // for a few shader functions
	#end

	//public var errorHandler:String->Void;
	#if LUA_ALLOWED
	public var lua:State = null;
	#else
	public var lua:Dynamic = null;
	#end
	public var camTarget:FlxCamera;
	public var scriptName:String = '';
	public var modFolder:String = null;
	public var closed:Bool = false;

	/** Memory-ledger registration id for this Lua state's RAM (0 = unregistered). */
	var vlogCodeId:Int = 0;

	/** Runtime half of the softmod sandbox; populated before Lua is created. */
	public var sandboxed:Bool = false;
	public var securityModName:String = null;
	public var securityAllowlist:Array<String> = [];

	#if HSCRIPT_ALLOWED
	public var hscript:HScript = null;
	#end

	public var callbacks:Map<String, Dynamic> = [];
	public static var customFunctions:Map<String, Dynamic> = [];
	public static var registeredFunctions:Map<String, Dynamic> = [];

	#if LUA_ALLOWED
	private var _missingCalls:Map<String, Bool> = new Map();
	/** Hooks that already ran once; only filled while verbose Lua logging is on. */
	private var _diagCalled:Map<String, Bool> = null;
	#end

	public function new(scriptName:String, ?scriptCode:String) {
		#if LUA_ALLOWED
		this.scriptName = scriptName;
		final game:PlayState = PlayState.instance;
		final diagStart:Float = haxe.Timer.stamp();
		LuaDiagnostics.beginLoad(scriptName, scriptCode == null ? 'file' : 'inline source');

		// Read once, scan exactly those bytes, then execute the same buffer at
		// the end of this constructor. This avoids a scan/dofile race where a
		// mod could change the file in between, while still running the script
		// only after the engine API below has been registered (Psych parity).
		var source:String = scriptCode;
		// Why the source could not be read up front, if it could not.
		var readProblem:String = null;
		if(source == null)
		{
			#if sys
			try
			{
				if(FileSystem.exists(scriptName)) source = File.getContent(scriptName);
				else readProblem = 'the file does not exist on disk';
			}
			catch(e:Dynamic)
			{
				readProblem = Std.string(e);
			}
			#else
			readProblem = 'this target has no file system access';
			#end
			if(source == null && readProblem == null) readProblem = 'no content was returned';
		}
		diagSource(source, readProblem);

		var security = ModSecurity.checkScript(scriptName, source, 'lua');
		sandboxed = security.sandboxed;
		securityModName = security.modName;
		securityAllowlist = security.allowlist;
		modFolder = security.modFolder;
		ModSecurity.report(security, function(message:String) game.addTextToDebug(message, FlxColor.RED));
		if(LuaDiagnostics.verbose)
		{
			var sandboxState:String = 'not a mod script, runs unsandboxed';
			if(sandboxed) sandboxState = 'sandboxed';
			else if(security.optedOut)
				sandboxState = security.playerOverride == false ? 'sandbox turned off in the Mods menu (Mod Info)' : 'sandbox turned off in pack.json';
			LuaDiagnostics.log('  security: owner "${security.modName}", ' + sandboxState
				+ ', allowlist [' + securityAllowlist.join(', ') + '], ${security.findings.length} finding(s)');
		}
		if(security.findings.length > 0)
		{
			diagBlocked(security.findings, source == null ? readProblem : null);
			closed = true;
			return;
		}

		lua = LuaL.newstate();
		LuaL.openlibs(lua);

		// Keep the safe base/string/table/math functions required by normal mods,
		// but replace OS, IO, package, dynamic-code, and FFI entry points.
		if(sandboxed)
		{
			var bootstrapResult:Int = LuaL.dostring(lua, ModSecurity.luaBootstrap(securityAllowlist));
			if(bootstrapResult != Lua.OK)
			{
				var bootstrapError:String = Lua.tostring(lua, -1);
				reportSecurityRuntime('failed to initialise Lua sandbox: ' + bootstrapError);
				LuaDiagnostics.record(SANDBOX_FAILED, scriptName, bootstrapError);
				Lua.close(lua);
				lua = null;
				closed = true;
				return;
			}
			LuaDiagnostics.log('  sandbox: bootstrap installed');
		}

		game.luaArray.push(this);

		// Lua API
		set('Function_StopLua', Function_StopLua);
		set('Function_Stop', Function_Stop);
		set('Function_Continue', Function_Continue);
		set('luaDebugMode', false);
		set('luaDeprecatedWarnings', true);
		set('inChartEditor', false);
		set('modFolder', this.modFolder);

		// Song and week data
		set('curBpm', Conductor.bpm);
		set('bpm', PlayState.SONG.bpm);
		set('scrollSpeed', PlayState.SONG.speed);
		set('crochet', Conductor.crochet);
		set('stepCrochet', Conductor.stepCrochet);
		set('songLength', FlxG.sound.music.length);
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

		// Camera poo
		set('cameraX', 0);
		set('cameraY', 0);

		// Screen stuff
		set('screenWidth', FlxG.width);
		set('screenHeight', FlxG.height);

		// PlayState cringe nae nae nonsense
		set('curBeat', 0);
		set('curStep', 0);
		set('curDecBeat', 0);
		set('curDecStep', 0);

		set('score', 0);
		set('misses', 0);
		set('hits', 0);

		set('rating', 0);
		set('ratingName', '');
		set('hitTiming', '');
		set('noteDiff', 0);
		set('ratingFC', '');
		set('phoenixVersion', MainMenuState.phoenixEngineVersion.trim());
		set('version', MainMenuState.psychEngineVersion.trim());
		set('jsVersion', MainMenuState.psychEngineJSVersion.trim());

		set('inGameOver', false);
		set('mustHitSection', false);
		set('altAnim', false);
		set('gfSection', false);

		set('npsSpeedMult', game.npsSpeedMult);

		// these things are useless
		set('polyphonyOppo', game.polyphonyOppo);
		set('polyphonyBF', game.polyphonyBF);

		// Gameplay settings
		set('healthGainMult', game.healthGain);
		set('healthLossMult', game.healthLoss);
		set('playbackRate', game.playbackRate);
		set('instakillOnMiss', game.instakillOnMiss);
		set('botPlay', game.cpuControlled);
		set('practice', game.practiceMode);

		for (i in 0...4) {
			set('defaultPlayerStrumX' + i, 0);
			set('defaultPlayerStrumY' + i, 0);
			set('defaultOpponentStrumX' + i, 0);
			set('defaultOpponentStrumY' + i, 0);
		}

		// Default character positions woooo
		set('defaultBoyfriendX', game.BF_X);
		set('defaultBoyfriendY', game.BF_Y);
		set('defaultOpponentX', game.DAD_X);
		set('defaultOpponentY', game.DAD_Y);
		set('defaultGirlfriendX', game.GF_X);
		set('defaultGirlfriendY', game.GF_Y);

		// Character API
		set('boyfriendName', PlayState.SONG.player1 ?? 'bf');
		set('dadName', PlayState.SONG.player2 ?? 'dad');
		set('gfName', PlayState.SONG.gfVersion ?? 'gf');

		// Some settings, no jokes
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
		// Options -> Optimization -> Memory Profile (see backend.MemoryProfiles).
		set('memoryProfile', ClientPrefs.memoryProfile);
		set('lowMemoryMode', ClientPrefs.lowMemoryMode);
		set('shadersEnabled', ClientPrefs.shaders);
		set('scriptName', scriptName);
		set('currentModDirectory', Mods.currentModDirectory);

		// Noteskin and splash settings
		set('noteSkin', ClientPrefs.noteSkin);
		set('noteSkinPostfix', NoteHelpers.getNoteSkinPostfix());
		set('splashSkin', ClientPrefs.splashType);
		set('splashSkinPostfix', NoteSplash.getSplashSkinPostfix());

		// If you don't want this to show, you can use the lua script to change it
		set('user_path', CoolSystemStuff.getUserPath());
		set("user_name", CoolSystemStuff.getUsername());

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

		for (name => func in customFunctions) {
			if (func != null) {
				#if LUA_ALLOWED
				_missingCalls.remove(name);
				Convert.addCallback(lua, name, func);
				#end
			}
		}

		// Shader support
		// REFACTOR: extracted to psychlua.callbacks.ShaderCallbacks
	ShaderCallbacks.register(this);

	ScriptCallbacks.register(this);

	PropertyCallbacks.register(this);

	TweenCallbacks.register(this);

	InputCallbacks.register(this);

	GameCallbacks.register(this);

	SpriteCallbacks.register(this);

	SoundCallbacks.register(this);

	TextCallbacks.register(this);

	SaveDataCallbacks.register(this);

	#if sys
	FileCallbacks.register(this);
	#end

	DeprecatedCallbacks.register(this);

	EffectCallbacks.register(this);

	MiscCallbacks.register(this);

	HardwareCallbacks.register(this);
	WindowCallbacks.register(this);
// 4th-wall-breaking ("META_HORROR") system effects (issue #94)
	MetaHorrorCallbacks.register(this);

	#if ACHIEVEMENTS_ALLOWED Achievements.addLuaCallbacks(lua); #end
	#if HSCRIPT_ALLOWED HScript.implement(this); #end
	CustomSubstate.implement(this);
	#if flxanimate FlxAnimateFunctions.implement(this); #end

	CameraCallbacks.register(this);

	ModchartCallbacks.register(this);

		for (name => func in registeredFunctions) {
			if (func != null) {
				#if LUA_ALLOWED
				_missingCalls.remove(name);
				Convert.addCallback(lua, name, func);
				#end
			}
		}

		// Execute the script's top-level code only now, with every engine
		// global and callback already registered — exactly like upstream
		// Psych Engine (dofile at the end of the constructor) and this
		// engine's own PythonScript/HScript hosts. Psych mods routinely call
		// setProperty/debugPrint/precacheImage and read songName/screenWidth
		// at the top level; running earlier made those nil calls abort the
		// whole script ("soft mods not working"). The buffer executed here is
		// the exact one ModSecurity scanned above, so the scan/execute race
		// protection is preserved.
		lastCalledScript = this;
		// Verbose only: remember which global functions exist before the script
		// runs, so the ones it defines (its hooks) can be listed afterwards.
		var diagApi:Map<String, Bool> = LuaDiagnostics.verbose ? globalFunctionSet() : null;
		if(diagApi != null) LuaDiagnostics.log('  api: ' + Lambda.count(diagApi) + ' global functions are available to the script');
		try
		{
			var result:Int;
			// Whether the chunk got past the compiler; tells a syntax error from
			// top-level code that raised while running.
			var compiled:Bool;
			if(source != null)
			{
				result = LuaL.loadbuffer(lua, source, haxe.io.Bytes.ofString(source).length, '@' + scriptName);
				compiled = result == Lua.OK;
				if(result == Lua.OK) result = Lua.pcall(lua, 0, 0, 0);
			}
			else
			{
				result = LuaL.dofile(lua, scriptName);
				compiled = result != Lua.ERRSYNTAX && result != Lua.ERRFILE;
			}

			if(result != Lua.OK)
			{
				var resultStr:String = Lua.tostring(lua, -1);
				if(resultStr == null) resultStr = 'Unknown Lua load error';
				if(sandboxed && resultStr.indexOf('[ModSecurity]') >= 0)
					resultStr = ModSecurity.formatRuntimeBlock(securityModName, this.scriptName, resultStr);
				trace('Error on lua script! ' + resultStr);
				diagLoadFailed(compiled, result, resultStr, source);
				#if windows
				lime.app.Application.current.window.alert(resultStr, 'Error on lua script!');
				#else
				LuaUtils.luaTrace(lua, 'Error loading lua script: "$scriptName"\n' + resultStr, true, false, FlxColor.RED);
				#end
				game.luaArray.remove(this);
				Lua.close(lua);
				lua = null;
				closed = true;
				return;
			}
		}
		catch(e:Dynamic)
		{
			game.luaArray.remove(this);
			if(lua != null) Lua.close(lua);
			lua = null;
			closed = true;
			trace(e);
			LuaDiagnostics.record(ENGINE_ERROR, scriptName, Std.string(e));
			LuaDiagnostics.error('$scriptName did not load: the engine raised an exception while running it: $e');
			return;
		}

		trace('lua file loaded succesfully:' + scriptName);
		diagLoaded(diagApi, diagStart);

		// Register this Lua state with the per-area RAM ledger. lua_gc(GCCOUNT)
		// is an O(1) read of the Lua allocator total, re-sampled every frame, so
		// mod-code RAM in the vlog is exact rather than estimated.
		vlogCodeId = backend.MemoryLedger.registerCode(scriptName, 'lua', modFolder, function():Float {
			if(closed || lua == null) return 0.0;
			try {
				return Lua.gc(lua, Lua.GCCOUNT, 0) * 1024.0 + Lua.gc(lua, Lua.GCCOUNTB, 0);
			} catch(e:Dynamic) {
				return 0.0;
			}
		});

		call('onCreate', []);
		#end
	}

	/** Log a runtime guard failure to both the mod console and the process log. */
	public function reportSecurityRuntime(capability:String, ?line:Int = 0):String
	{
		var message:String = ModSecurity.formatRuntimeBlock(securityModName, scriptName, capability, line);
		trace(message);
		if(PlayState.instance != null) PlayState.instance.addTextToDebug(message, FlxColor.RED);
		return message;
	}

	public function reportSecurityFinding(context:String, finding:ScriptSecurityFinding):Void
	{
		reportSecurityRuntime('$context (${finding.rule}) at embedded line ${finding.line}: ${finding.description} | ${finding.snippet}');
	}

	public inline function allowsSecurityRule(rule:String):Bool
		return ModSecurity.isRuleAllowed(rule, securityAllowlist);

	public function allowClassAccess(className:String):Bool
	{
		if(!sandboxed || !ModSecurity.isPrivilegedClass(className) || allowsSecurityRule('engine.native-class')) return true;
		reportSecurityRuntime('privileged class reflection: $className');
		return false;
	}

	public function addLocalCallback(name:String, myFunction:Dynamic)
	{
		#if LUA_ALLOWED
		_missingCalls.remove(name);
		#end
		callbacks.set(name, myFunction);
		#if LUA_ALLOWED
		Convert.addCallback(lua, name, null); // just so that it gets called
		#end
	}

	public static function registerFunction(name:String, func:Dynamic):Void
		registeredFunctions.set(name, func);

	public static function setVarInArray(instance:Dynamic, variable:String, value:Dynamic):Any
		return LuaUtils.setVarInArray(instance, variable, value);

	public static function getVarInArray(instance:Dynamic, variable:String):Any
		return LuaUtils.getVarInArray(instance, variable);

	inline static function getTextObject(name:String):FlxText
	{
		return PlayState.instance.modchartTexts.exists(name) ? PlayState.instance.modchartTexts.get(name) : Reflect.getProperty(PlayState.instance, name);
	}

	#if (SHADERS_ALLOWED)
	public function getShader(obj:String):FlxRuntimeShader
	{
		var killMe:Array<String> = obj.split('.');
		var leObj:FlxSprite = getObjectDirectly(killMe[0]);
		if(killMe.length > 1) {
			leObj = getVarInArray(getPropertyLoopThingWhatever(killMe), killMe[killMe.length-1]);
		}

		if(leObj != null) {
			var shader:Dynamic = leObj.shader;
			var shader:FlxRuntimeShader = shader;
			return shader;
		}
		return null;
	}
	#end

	function initLuaShader(name:String, ?glslVersion:Int = 120)
	{
		if(!ClientPrefs.shaders) return false;

		#if (SHADERS_ALLOWED)
		if(PlayState.instance.runtimeShaders.exists(name))
		{
			#if LUA_ALLOWED
			LuaUtils.luaTrace(lua, 'Shader $name was already initialized!');
			#end
			return true;
		}

		final sources = shaders.ShaderSource.load(name);
		if (sources != null)
		{
			PlayState.instance.runtimeShaders.set(name, sources);
			return true;
		}
		#if LUA_ALLOWED
		LuaUtils.luaTrace(lua, 'Missing shader $name .frag AND .vert files, or one of its imports could not be loaded!', false, false, FlxColor.RED);
		#else
		trace('Missing shader $name .frag AND .vert files, or one of its imports could not be loaded!');
		#end
		#else
		trace('This platform doesn\'t support Runtime Shaders!');
		#end
		return false;
	}

	function getGroupStuff(leArray:Dynamic, variable:String) {
		var killMe:Array<String> = variable.split('.');
		if(killMe.length > 1) {
			var coverMeInPiss:Dynamic = Reflect.getProperty(leArray, killMe[0]);
			for (i in 1...killMe.length-1) {
				coverMeInPiss = Reflect.getProperty(coverMeInPiss, killMe[i]);
			}
			switch(Type.typeof(coverMeInPiss)){
				case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
					return coverMeInPiss.get(killMe[killMe.length-1]);
				default:
					return Reflect.getProperty(coverMeInPiss, killMe[killMe.length-1]);
			};
		}
		switch(Type.typeof(leArray)){
			case ValueType.TClass(haxe.ds.StringMap) | ValueType.TClass(haxe.ds.ObjectMap) | ValueType.TClass(haxe.ds.IntMap) | ValueType.TClass(haxe.ds.EnumValueMap):
				return leArray.get(variable);
			default:
				return Reflect.getProperty(leArray, variable);
		};
	}

	function loadFrames(spr:FlxSprite, image:String, spriteType:String)
	{
		switch(spriteType.toLowerCase().trim())
		{
			// it never seemed like anyone used this, so it's gone. We've got flxanimate anyway
			/*
			case "texture", "textureatlas", "tex":
				case "texture_noaa", "textureatlas_noaa", "tex_noaa":
					// Deprecated loader â€” only kept for legacy support
					// You should use FlxAnimate instead!
					spr.frames = AtlasFrameMaker.construct(
						image,
						null,
						spriteType.indexOf("_noaa") == -1
					);
					trace("Using legacy TextureAtlas loader. Consider migrating to FlxAnimate.");
			*/

			case 'aseprite' | 'jsoni8':
				spr.frames = Paths.getAsepriteAtlas(image);

			case "packer" | "packeratlas" | "pac":
				spr.frames = Paths.getPackerAtlas(image);

			default:
				spr.frames = Paths.getSparrowAtlas(image);
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
		var sexyProp:Dynamic = getObjectDirectly(variables[0]);
		if(variables.length > 1)
			sexyProp = getVarInArray(getPropertyLoopThingWhatever(variables), variables[variables.length-1]);

		return sexyProp;
	}

	function cancelTimer(tag:String) {
		if(PlayState.instance.modchartTimers.exists(tag)) {
			var theTimer:FlxTimer = PlayState.instance.modchartTimers.get(tag);
			theTimer.cancel();
			theTimer.destroy();
			PlayState.instance.modchartTimers.remove(tag);
		}
	}

	public var lastCalledFunction:String = '';
	public static var lastCalledScript:FunkinLua = null;
	public function call(func:String, args:Array<Dynamic>):Dynamic {
		#if LUA_ALLOWED
		if(closed) return Function_Continue;

		lastCalledFunction = func;
		lastCalledScript = this;
		try {
			if(lua == null) return Function_Continue;

			if(_missingCalls.exists(func)) return Function_Continue;

			Lua.getglobal(lua, func);
			var type:Int = Lua.type(lua, -1);

			if (type != Lua.TFUNCTION) {
				if (type > Lua.TNIL)
				{
					LuaUtils.luaTrace(lua, "ERROR (" + func + "): attempt to call a " + LuaUtils.typeToString(type) + " value", false, false, FlxColor.RED);
					diagHookFailed(func, 'the global "' + func + '" holds a ' + LuaUtils.typeToString(type)
						+ ' value, not a function, so the hook can never run');
				}

				_missingCalls.set(func, true);
				Lua.pop(lua, 1);
				return Function_Continue;
			}

			for (arg in args) Convert.toLua(lua, arg);
			var status:Int = Lua.pcall(lua, args.length, 1, 0);

			// Checks if it's not successful, then show a error.
			if (status != Lua.OK) {
				var error:String = LuaUtils.getErrorMessage(lua, status);
				if(sandboxed && error != null && error.indexOf('[ModSecurity]') >= 0)
					error = ModSecurity.formatRuntimeBlock(securityModName, scriptName, error);
				LuaUtils.luaTrace(lua, "ERROR (" + func + "): " + error, false, false, FlxColor.RED);
				diagHookFailed(func, error);
				return Function_Continue;
			}

			// If successful, pass and then return the result.
			var result:Dynamic = cast Convert.fromLua(lua, -1);
			if (result == null) result = Function_Continue;

			Lua.pop(lua, 1);
			if(LuaDiagnostics.verbose) diagFirstRun(func, result);
			if(closed)
			{
				LuaDiagnostics.log('$scriptName called close() during $func: it is stopped and gets no more hooks');
				stop();
			}
			return result;
		}
		catch (e:Dynamic) {
			trace(e);
			diagHookFailed(func, 'the engine raised an exception while calling it: ' + Std.string(e));
		}
		#end
		return Function_Continue;
	}

	static function addAnimByIndices(obj:String, name:String, prefix:String, indices:String, framerate:Int = 24, loop:Bool = false)
	{
		return LuaUtils.addAnimByIndices(obj, name, prefix, indices, framerate, loop);
	}

	public static function getPropertyLoopThingWhatever(killMe:Array<String>, ?checkForTextsToo:Bool = true, ?getProperty:Bool=true):Dynamic
		return LuaUtils.getPropertyLoopThingWhatever(killMe, checkForTextsToo, getProperty);

	public static function getObjectDirectly(objectName:String, ?checkForTextsToo:Bool = true):Dynamic
		return LuaUtils.getObjectDirectly(objectName, checkForTextsToo);

	#if LUA_ALLOWED
	/** Names of every global that currently holds a function (verbose Lua logging only). */
	function globalFunctionSet():Map<String, Bool>
	{
		var names:Map<String, Bool> = new Map();
		if(lua == null) return names;

		Lua.pushnil(lua);
		while(Lua.next(lua, Lua.GLOBALSINDEX) != 0)
		{
			// Read string keys only: lua_tostring would convert a number key in
			// place and derail lua_next.
			if(Lua.type(lua, -2) == Lua.TSTRING && Lua.type(lua, -1) == Lua.TFUNCTION)
			{
				var name:String = Lua.tostring(lua, -2);
				names.set(name, true);
			}
			Lua.pop(lua, 1);
		}
		return names;
	}

	/** Report what the source buffer looks like before anything is done with it. */
	function diagSource(source:String, readProblem:String):Void
	{
		if(source == null)
		{
			// Not fatal yet: a script outside the mod sandbox is handed to
			// luaL_dofile instead, which reports its own error if it fails too.
			LuaDiagnostics.log('  source: could not be read up front ($readProblem)');
			return;
		}
		var facts = LuaDiagnostics.inspectSource(source, LuaDiagnostics.verbose);
		for(problem in facts.problems) LuaDiagnostics.warn('$scriptName: $problem');
		if(!LuaDiagnostics.verbose) return;
		LuaDiagnostics.log('  source: ${facts.bytes} bytes, ${facts.lines} lines');
		for(note in facts.notes) LuaDiagnostics.log('  note: $note');
	}

	/**
	 * The ModSecurity source scan refused the script: say how to get past it.
	 * `readProblem` is set when the refusal is really an unreadable file.
	 */
	function diagBlocked(findings:Array<ScriptSecurityFinding>, readProblem:String):Void
	{
		if(readProblem != null)
		{
			LuaDiagnostics.record(UNREADABLE, scriptName, readProblem);
			LuaDiagnostics.error('$scriptName did not load: it could not be read ($readProblem), '
				+ 'and a mod script has to be readable so it can be security-scanned before it runs.');
			return;
		}

		var rules:Array<String> = [for(finding in findings) finding.rule];
		var where:Array<String> = [for(finding in findings) '${finding.rule} (line ${finding.line})'];
		LuaDiagnostics.record(BLOCKED, scriptName, where.join(', '));
		LuaDiagnostics.error('$scriptName was blocked by ModSecurity before it ran: ' + where.join(', ') + '. '
			+ LuaDiagnostics.securityHint(modFolder, rules));
	}

	/** The top-level chunk did not load: tell a syntax error from code that raised, and show the line. */
	function diagLoadFailed(compiled:Bool, status:Int, message:String, source:String):Void
	{
		LuaDiagnostics.record(LuaDiagnostics.loadFailureOutcome(compiled, status), scriptName, message);
		LuaDiagnostics.error('$scriptName did not load: ' + LuaDiagnostics.describeLoadFailure(compiled, status, message));
		for(line in LuaDiagnostics.sourceExcerpt(source, LuaDiagnostics.errorLine(message, scriptName))) LuaDiagnostics.emit(line);
	}

	/** The top-level chunk ran: record it and, in verbose mode, list what the script gave the engine to call. */
	function diagLoaded(apiBefore:Map<String, Bool>, startedAt:Float):Void
	{
		LuaDiagnostics.record(LOADED, scriptName);

		// A hook dispatched while the chunk was still running (a top-level
		// triggerEvent, for instance) was looked up before the script defined
		// it and is now cached as missing, so it would never be called.
		for(name in _missingCalls.keys())
		{
			Lua.getglobal(lua, name);
			var definedNow:Bool = Lua.type(lua, -1) == Lua.TFUNCTION;
			Lua.pop(lua, 1);
			if(definedNow)
			{
				LuaDiagnostics.warn('$scriptName defines $name, but the engine looked that hook up before the script had finished loading '
					+ 'and cached it as missing: it will not be called. Do not trigger engine events from top-level code; do it in onCreate.');
			}
		}

		if(apiBefore == null) return;

		if(closed)
			LuaDiagnostics.log('  note: the top-level code called close(), so the script is inert: none of its hooks will run, not even onCreate');
		var defined:Array<String> = [for(name in globalFunctionSet().keys()) if(!apiBefore.exists(name)) name];
		var review = LuaDiagnostics.reviewFunctions(defined, true);
		LuaDiagnostics.log('  hooks defined (${review.hooks.length}): ' + (review.hooks.length == 0 ? 'none' : review.hooks.join(', ')));
		if(review.others.length > 0) LuaDiagnostics.log('  other global functions: ' + review.others.join(', '));
		for(miss in review.nearMisses)
		{
			LuaDiagnostics.warn('$scriptName defines "${miss.name}", which the engine never calls. Did you mean the hook "${miss.hook}"? '
				+ 'Hook names are case-sensitive.');
		}
		if(review.hooks.length == 0)
			LuaDiagnostics.log('  note: no hook is defined as a global function, so the engine has nothing to call after the top-level code');
		LuaDiagnostics.log('  loaded in ' + Math.round((haxe.Timer.stamp() - startedAt) * 10000) / 10 + ' ms');
	}

	/** A hook raised (or is not callable). Printed once per distinct error; see LuaDiagnostics.hookFailure. */
	function diagHookFailed(func:String, message:String):Void
	{
		var line:String = LuaDiagnostics.hookFailure(scriptName, func, message);
		if(line != null) LuaDiagnostics.error(line);
	}

	/** Verbose only: the first successful run of each hook, which proves the engine does call it. */
	function diagFirstRun(func:String, result:Dynamic):Void
	{
		if(_diagCalled == null) _diagCalled = new Map();
		if(_diagCalled.exists(func)) return;
		_diagCalled.set(func, true);

		var returned:String = Std.string(result);
		if(result == Function_Continue) returned = 'Function_Continue';
		else if(result == Function_Stop) returned = 'Function_Stop';
		else if(result == Function_StopLua) returned = 'Function_StopLua';
		LuaDiagnostics.log('hook $func ran for the first time in $scriptName (returned $returned)');
	}
	#end

	public function set(variable:String, data:Dynamic) {
		#if LUA_ALLOWED
		if (lua == null)
			return;

		if (Reflect.isFunction(data)) {
			// Bind as a callable Lua function
			_missingCalls.remove(variable);
			Convert.addCallback(lua, variable, data);
			return;
		}

		// Otherwise, treat it like a variable
		_missingCalls.remove(variable);
		Convert.toLua(lua, data);
		Lua.setglobal(lua, variable);
		#end
	}

	public function stop() {
		#if LUA_ALLOWED
		// Drop the ledger registration before the state is freed so its
		// byte-count provider is never called against a closed Lua state.
		backend.MemoryLedger.unregisterCode(vlogCodeId);
		vlogCodeId = 0;
		closed = true;
		if(lua == null) {
			return;
		}

		Lua.close(lua);
		lua = null;
		#if HSCRIPT_ALLOWED
		if(hscript != null) hscript.stop();
		hscript = null;
		#end
		#end
	}

	public static inline function getInstance()
	{
		return LuaUtils.getInstance();
	}
}
#if LUA_ALLOWED
typedef State = cpp.RawPointer<Lua_State>;
#end
// hi guys, my name is "secret"!
