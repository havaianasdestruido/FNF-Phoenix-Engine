package play.helpers;

// REFACTOR: explicit imports for shader subtypes
import shaders.ErrorHandledShader.ErrorHandledRuntimeShader;

import backend.ClientPrefs;
import backend.Paths;
#if MODS_ALLOWED
import backend.Mods;
#end

import play.PlayState;

// REFACTOR: script/shader plumbing extracted from play.PlayState
@:access(play.PlayState)
@:access(backend.MusicBeatState)
class PlayStateScripts
{
	#if SHADERS_ALLOWED
	/**
	 * Executes the `createRuntimeShader` operation.
	 * @param state Input value for `state`.
	 * @param shaderName Input value for `shaderName`.
	 * @return Result produced by `createRuntimeShader`, when applicable.
	 */
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
		return new ErrorHandledRuntimeShader(shaderName, arr[0], arr[1]);
		#else
		FlxG.log.warn("Platform unsupported for Runtime Shaders!");
		return null;
		#end
	}

	/**
	 * Executes the `initLuaShader` operation.
	 * @param state Input value for `state`.
	 * @param name Input value for `name`.
	 * @return Result produced by `initLuaShader`, when applicable.
	 */
	public static function initLuaShader(state:PlayState, name:String)
	{
		if(!ClientPrefs.shaders) return false;

		if(state.runtimeShaders.exists(name))
		{
			FlxG.log.warn('Shader $name was already initialized!');
			return true;
		}

		#if MODS_ALLOWED
		var foldersToCheck:Array<String> = [Paths.mods('shaders/')];
		if(Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			foldersToCheck.insert(0, Paths.mods(Mods.currentModDirectory + '/shaders/'));

		for(mod in Mods.getGlobalMods())
			foldersToCheck.insert(0, Paths.mods(mod + '/shaders/'));
		#else
		var foldersToCheck:Array<String> = [];
		#end

		for (folder in foldersToCheck)
		{
			#if sys
			if(FileSystem.exists(folder))
			{
				var frag:String = folder + name + '.frag';
				var vert:String = folder + name + '.vert';
				var found:Bool = false;
				if(FileSystem.exists(frag))
				{
					frag = File.getContent(frag);
					found = true;
				}
				else frag = null;

				if (FileSystem.exists(vert))
				{
					vert = File.getContent(vert);
					found = true;
				}
				else vert = null;

				if(found)
				{
					state.runtimeShaders.set(name, [frag, vert]);
					//trace('Found shader $name!');
					return true;
				}
			}
			#end
		}
		FlxG.log.warn('Missing shader $name .frag AND .vert files!');
		return false;
	}
	#end

	/**
	 * Executes the `addTextToDebug` operation.
	 * @param state Input value for `state`.
	 * @param text Input value for `text`.
	 * @param color Input value for `color`.
	 * @return Result produced by `addTextToDebug`, when applicable.
	 */
	public static function addTextToDebug(state:PlayState, text:String, color:FlxColor) {
		#if LUA_ALLOWED
		var newText:DebugLuaText = state.luaDebugGroup.recycle(DebugLuaText);
		newText.text = text;
		newText.color = color;
		newText.disableTime = 6;
		newText.alpha = 1;
		newText.setPosition(10, 8 - newText.height);
   		newText.setFormat(Paths.font("old_windows.ttf"));
		state.luaDebugGroup.forEachAlive(function(spr:DebugLuaText) {
			spr.y += newText.height + 2;
		});
		state.luaDebugGroup.add(newText);

		#if sys
		Sys.println(text);
		#end
		#end
	}

	/**
	 * Executes the `addShaderToCamera` operation.
	 * @param state Input value for `state`.
	 * @param cam Input value for `cam`.
	 * @param effect Input value for `effect`.
	 * @return Result produced by `addShaderToCamera`, when applicable.
	 */
	public static function addShaderToCamera(state:PlayState, cam:String,effect:Dynamic){//STOLE FROM ANDROMEDA	// actually i got it from old psych engine
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				state.camHUD.addShader(effect.shader);
			case 'camother' | 'other':
				state.camOther.addShader(effect.shader);
			case 'camgame' | 'game':
				state.camGame.addShader(effect.shader);
			default:
				#if LUA_ALLOWED
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

	/**
	 * Executes the `removeShaderFromCamera` operation.
	 * @param state Input value for `state`.
	 * @param cam Input value for `cam`.
	 * @param effect Input value for `effect`.
	 * @return Result produced by `removeShaderFromCamera`, when applicable.
	 */
	public static function removeShaderFromCamera(state:PlayState, cam:String,effect:Dynamic){
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				if(state.camHUD.removeShader(effect.shader))
				{
					trace("Removed shader successfully");
				}
				else
				{
					trace("Shader wasn't found");
				}
			case 'camother' | 'other':
				if(state.camOther.removeShader(effect.shader))
				{
					trace("Removed shader successfully");
				}
				else
				{
					trace("Shader wasn't found");
				}
			case 'camgame' | 'game':
				if(state.camGame.removeShader(effect.shader))
				{
					trace("Removed shader successfully");
				}
				else
				{
					trace("Shader wasn't found");
				}
			default:
				#if LUA_ALLOWED
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

	/**
	 * Executes the `clearShaderFromCamera` operation.
	 * @param state Input value for `state`.
	 * @param cam Input value for `cam`.
	 * @return Result produced by `clearShaderFromCamera`, when applicable.
	 */
	public static function clearShaderFromCamera(state:PlayState, cam:String){
		switch(cam.toLowerCase()) {
			case 'camhud' | 'hud':
				state.camHUD.filters = [];
			case 'camother' | 'other':
				state.camOther.filters = [];
			case 'camgame' | 'game':
				state.camGame.filters = [];
			default:
				state.camGame.filters = [];
		}
	}

	/**
	 * Executes the `getLuaObject` operation.
	 * @param state Input value for `state`.
	 * @param tag Input value for `tag`.
	 * @param text Input value for `text`.
	 * @return Result produced by `getLuaObject`, when applicable.
	 */
	public static function getLuaObject(state:PlayState, tag:String, text:Bool=true):FlxSprite {
		#if LUA_ALLOWED
		if(state.modchartSprites.exists(tag)) return state.modchartSprites.get(tag);
		if(text && state.modchartTexts.exists(tag)) return state.modchartTexts.get(tag);
		if(state.variables.exists(tag)) return state.variables.get(tag);
		#end
		return null;
	}

	#if LUA_ALLOWED
	/**
	 * Executes the `startLuasOnFolder` operation.
	 * @param state Input value for `state`.
	 * @param luaFile Input value for `luaFile`.
	 * @return Result produced by `startLuasOnFolder`, when applicable.
	 */
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
	/**
	 * Executes the `startPythonScriptOnFolder` operation.
	 * @param state Input value for `state`.
	 * @param pyFile Input value for `pyFile`.
	 * @return Result produced by `startPythonScriptOnFolder`, when applicable.
	 */
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
}
