package play.helpers;

import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;
import shaders.ShaderWarmup;

import backend.ClientPrefs;
import backend.LuaDiagnostics;
import backend.Paths;
#if MODS_ALLOWED
#end

import play.PlayState;
#if HSCRIPT_ALLOWED
import psychlua.DebugLuaText;
#end

@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateScripts
{
	#if SHADERS_ALLOWED
	public static function createRuntimeShader(state:PlayState, shaderName:String):ErrorHandledRuntimeShader
	{
		if(!ClientPrefs.shaders) return new ErrorHandledRuntimeShader(shaderName);

		#if (MODS_ALLOWED && SHADERS_ALLOWED)
		if(!state.runtimeShaders.exists(shaderName) && !initLuaShader(state, shaderName))
		{
			FlxG.log.warn('Shader $shaderName is missing!');
			return new ErrorHandledRuntimeShader(shaderName);
		}

		var arr:Array<String> = state.runtimeShaders.get(shaderName);
		var shader = new ErrorHandledRuntimeShader(shaderName, arr[0], arr[1]);
		// [P3] Shader warm-up: compile it with the stage's shaders while the
		// state is loading instead of on the frame that first draws it.
		#if !neko
		ShaderWarmup.track(shader);
		#end
		return shader;
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	public static function initLuaShader(state:PlayState, name:String)
	{
		if(!ClientPrefs.shaders) return false;

		if(state.runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		final sources = shaders.ShaderSource.load(name);
		if (sources != null)
		{
			state.runtimeShaders.set(name, sources);
			return true;
		}
		FlxG.log.warn('Missing shader $name .frag AND .vert files, or one of its imports could not be loaded!');
		return false;
	}
	#end

	public static function addTextToDebug(state:PlayState, text:String, color:FlxColor, echo:Bool = true) {
		#if LUA_ALLOWED
		var newText:DebugLuaText = state.luaDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		// Format before measuring: the height used for the position must be the
		// height the text is shown with, or its first use ends up above the screen.
		newText.setFormat(Paths.font("old_windows.ttf"));
		newText.setPosition(10, 8 - newText.height);
		state.luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		state.luaDebugGroup.add(newText);

		#if sys
		if(echo) Sys.println(text);
		#end
		#elseif PYTHON_ALLOWED
		var newText:DebugLuaText = state.pythonDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		// Format before measuring: the height used for the position must be the
		// height the text is shown with, or its first use ends up above the screen.
		newText.setFormat(Paths.font("old_windows.ttf"));
		newText.setPosition(10, 8 - newText.height);
		state.pythonDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		state.pythonDebugGroup.add(newText);

		#if sys
		if(echo) Sys.println(text);
		#end
		#elseif HSCRIPT_ALLOWED
		var newText:DebugLuaText = state.hscriptDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		// Format before measuring: the height used for the position must be the
		// height the text is shown with, or its first use ends up above the screen.
		newText.setFormat(Paths.font("old_windows.ttf"));
		newText.setPosition(10, 8 - newText.height);
		state.hscriptDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		state.hscriptDebugGroup.add(newText);

		#if sys
		if(echo) Sys.println(text);
		#end
		#end
	}

	/** Verbose Lua logging: the facts every script lookup of the current song depends on. */
	public static function luaDiagContext():Array<String>
	{
		var song:String = PlayState.SONG.song;
		var lines:Array<String> = ['song "' + song + '" -> data folder "' + Paths.formatToSongPath(song) + '", stage "' + PlayState.curStage + '"'];
		#if sys
		lines.push('working directory: ' + Sys.getCwd());
		#end
		#if MODS_ALLOWED
		// Safe Mode (states.RecoveryState) can start a session without any mod;
		// Paths.mods() then points at a place that cannot exist.
		if(backend.RecoveryBoot.disableMods)
			lines.push('note: Safe Mode started this session with all mods disabled: nothing under mods/ is searched. Restart the game to load mods again.');
		var currentMod:String = Mods.currentModDirectory;
		var globalMods:Array<String> = Mods.getGlobalMods();
		lines.push('current mod: ' + (currentMod == null || currentMod.length == 0 ? '<none>' : currentMod)
			+ '; global mods ("runsGlobally" in pack.json): [' + globalMods.join(', ') + ']');
		#if sys
		// mods/<mod>/scripts/ is only searched for the current mod and for global
		// mods: an enabled mod that is neither contributes no global script.
		for(mod in Mods.parseList().enabled)
		{
			if(mod == currentMod || globalMods.contains(mod)) continue;
			var scripts:Int = LuaDiagnostics.countLuaFiles(Paths.mods(mod + '/scripts/'));
			if(scripts > 0)
				lines.push('note: mod "' + mod + '" is enabled and has ' + scripts + ' .lua file(s) in scripts/, but they are not loaded for this song: '
					+ 'it is not the current mod and its pack.json does not set "runsGlobally": true');
		}
		#end
		#end
		return lines;
	}

	#if !LUA_ALLOWED
	/**
	 * This build has no Lua VM. Remember a script that a Lua build would have
	 * loaded by name (stage, character, note type, event), so the player is
	 * told why it does nothing instead of the file being ignored without a
	 * word (see LuaDiagnostics.reportSummary).
	 */
	public static function noteUnsupportedLua(luaFile:String):Void
	{
		#if sys
		var path:String = Paths.getPreloadPath(luaFile);
		#if MODS_ALLOWED
		var modPath:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(modPath)) path = modPath;
		#end
		if(FileSystem.exists(path)) LuaDiagnostics.lookupUnsupported(luaFile, path);
		#end
	}
	#end

	public static function addShaderToCamera(state:PlayState, cam:String,effect:Dynamic){//STOLE FROM ANDROMEDA	// actually i got it from old psych engine
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				state.camHUD.addShader(effect.shader);
			case 'camnotes' | 'notes' | 'camstrum' | 'strum':
				(state.camNotes != null ? state.camNotes : state.camHUD).addShader(effect.shader);
			case 'camother' | 'other':
				state.camOther.addShader(effect.shader);
			case 'camgame' | 'game':
				state.camGame.addShader(effect.shader);
			default:
				#if (LUA_ALLOWED || PYTHON_ALLOWED)
				if(state.modchartSprites.exists(cam)) {
					Reflect.setProperty(state.modchartSprites.get(cam),"shader",effect.shader);
				} else if(state.modchartTexts.exists(cam)) {
					Reflect.setProperty(state.modchartTexts.get(cam),"shader",effect.shader);
				} else
				#end
				{
					var OBJ = Reflect.getProperty(PlayState.instance,cam);
					Reflect.setProperty(OBJ,"shader", effect.shader);
				}
		}
 	}

	public static function removeShaderFromCamera(state:PlayState, cam:String,effect:Dynamic){
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				// No per-call trace here: this is reachable from update paths and mod
				// scripts, and leftover debug traces spam the console at 60fps (#69).
				state.camHUD.removeShader(effect.shader);
			case 'camnotes' | 'notes' | 'camstrum' | 'strum':
				(state.camNotes != null ? state.camNotes : state.camHUD).removeShader(effect.shader);
			case 'camother' | 'other':
				state.camOther.removeShader(effect.shader);
			case 'camgame' | 'game':
				state.camGame.removeShader(effect.shader);
			default:
				#if (LUA_ALLOWED || PYTHON_ALLOWED)
				if(state.modchartSprites.exists(cam)) {
					Reflect.setProperty(state.modchartSprites.get(cam),"shader",null);
				} else if(state.modchartTexts.exists(cam)) {
					Reflect.setProperty(state.modchartTexts.get(cam),"shader",null);
				} else
				#end
				{
					var OBJ = Reflect.getProperty(PlayState.instance,cam);
					Reflect.setProperty(OBJ,"shader", null);
				}
			}
	}

	public static function clearShaderFromCamera(state:PlayState, cam:String){
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				state.camHUD.filters = [];
			case 'camnotes' | 'notes' | 'camstrum' | 'strum':
				(state.camNotes != null ? state.camNotes : state.camHUD).filters = [];
			case 'camother' | 'other':
				state.camOther.filters = [];
			case 'camgame' | 'game':
				state.camGame.filters = [];
			default:
				state.camGame.filters = [];
		}
	}

	public static function getLuaObject(state:PlayState, tag:String, text:Bool=true):FlxSprite {
		#if (LUA_ALLOWED || PYTHON_ALLOWED)
		if(state.modchartSprites.exists(tag)) return state.modchartSprites.get(tag);
		if(text && state.modchartTexts.exists(tag)) return state.modchartTexts.get(tag);
		if(state.variables.exists(tag)) return state.variables.get(tag);
		#end
		return null;
	}

	#if LUA_ALLOWED
	public static function startLuasOnFolder(state:PlayState, luaFile:String)
	{
		for (script in state.luaArray)
		{
			if(script.scriptName == luaFile) return false;
		}

		#if MODS_ALLOWED
		var luaToLoad:String = Paths.modFolders(luaFile);
		if(FileSystem.exists(luaToLoad))
		{
			new FunkinLua(luaToLoad);
			return true;
		}
		else
		{
			luaToLoad = Paths.getPreloadPath(luaFile);
			if(FileSystem.exists(luaToLoad))
			{
				new FunkinLua(luaToLoad);
				return true;
			}
		}
		#elseif sys
		var luaToLoad:String = Paths.getPreloadPath(luaFile);
		if(OpenFlAssets.exists(luaToLoad))
		{
			new FunkinLua(luaToLoad);
			return true;
		}
		#end
		return false;
	}
	#end

	#if PYTHON_ALLOWED
	public static function startPythonScriptOnFolder(state:PlayState, pyFile:String)
	{
		for (script in state.pythonArray)
		{
			if(script.scriptName == pyFile) return false;
		}

		#if MODS_ALLOWED
		var pyToLoad:String = Paths.modFolders(pyFile);
		if(FileSystem.exists(pyToLoad))
		{
			new PythonScript(pyToLoad);
			return true;
		}
		else
		{
			pyToLoad = Paths.getPreloadPath(pyFile);
			if(FileSystem.exists(pyToLoad))
			{
				new PythonScript(pyToLoad);
				return true;
			}
		}
		#elseif sys
		var pyToLoad:String = Paths.getPreloadPath(pyFile);
		if(OpenFlAssets.exists(pyToLoad))
		{
			new PythonScript(pyToLoad);
			return true;
		}
		#end
		return false;
	}
	#end

	#if HSCRIPT_ALLOWED
	public static function startHScriptOnFolder(state:PlayState, hxFile:String)
	{
		// Resolution/dedup lives on PlayState (shared with addHScript()).
		return state.startHScriptOnFolder(hxFile);
	}
	#end
}
