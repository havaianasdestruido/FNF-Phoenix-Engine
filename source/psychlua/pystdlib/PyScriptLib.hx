package psychlua.pystdlib;

import backend.Paths;
import play.PlayState;
import psychlua.PythonScript;
#if sys
import sys.FileSystem;
import openfl.utils.Assets as OpenFlAssets;
#end
#if LUA_ALLOWED
import psychlua.Convert;
import psychlua.FunkinLua;
#end

// REFACTOR: extracted from psychlua.callbacks.ScriptCallbacks — Python parity (#87)
// Mirrors the Lua ScriptCallbacks inter-script API so Python mods can discover,
// call and share state with other scripts without silently falling back to nil.
class PyScriptLib
{
	public static function register(py:PythonScript):Void
	{
		// getRunningScripts():Array<String> — all currently loaded scripts (Lua + Python)
		PythonScript.registerFunction("getRunningScripts", function():Array<String>
		{
			var running:Array<String> = [];
			#if LUA_ALLOWED
			for (script in PlayState.instance.luaArray)
				running.push(script.scriptName);
			#end
			#if PYTHON_ALLOWED
			for (script in PlayState.instance.pythonArray)
				running.push(script.scriptName);
			#end
			return running;
		});

		// callOnLuas — compatibility alias: dispatches to Lua AND Python scripts
		PythonScript.registerFunction("callOnLuas", function(?funcName:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ignoreSelf:Bool = true, ?exclusions:Array<String>)
		{
			if (funcName == null) return null;
			if (args == null) args = [];
			if (exclusions == null) exclusions = [];
			// exclude caller itself when requested (mirrors Lua behaviour)
			if (ignoreSelf)
			{
				var caller = PythonScript.lastCalledScript;
				if (caller != null && !exclusions.contains(caller.scriptName))
					exclusions.push(caller.scriptName);
			}
			return PlayState.instance.callOnScripts(funcName, args, ignoreStops, exclusions);
		});

		// callOnScripts — preferred name (alias of callOnLuas)
		PythonScript.registerFunction("callOnScripts", function(?funcName:String, ?args:Array<Dynamic>, ignoreStops:Bool = false, ignoreSelf:Bool = true, ?exclusions:Array<String>)
		{
			if (funcName == null) return null;
			if (args == null) args = [];
			if (exclusions == null) exclusions = [];
			if (ignoreSelf)
			{
				var caller = PythonScript.lastCalledScript;
				if (caller != null && !exclusions.contains(caller.scriptName))
					exclusions.push(caller.scriptName);
			}
			return PlayState.instance.callOnScripts(funcName, args, ignoreStops, exclusions);
		});

		// callScript(path, func, args) — call a function on a specific script (Lua or Python)
		PythonScript.registerFunction("callScript", function(?file:String, ?funcName:String, ?args:Array<Dynamic>)
		{
			if (file == null || funcName == null) return null;
			if (args == null) args = [];
			var cervix = file;
			// accept with or without extension; normalise to full path lookup
			var candidates:Array<String> = [cervix];
			if (!cervix.endsWith(".lua") && !cervix.endsWith(".py"))
			{
				candidates.push(cervix + ".lua");
				candidates.push(cervix + ".py");
			}
			#if LUA_ALLOWED
			for (path in candidates)
			{
				var resolved = resolveScriptPath(path);
				if (resolved != null)
				{
					for (s in PlayState.instance.luaArray)
						if (s.scriptName == resolved) return s.call(funcName, args);
				}
			}
			#end
			#if PYTHON_ALLOWED
			for (path in candidates)
			{
				var resolved = resolveScriptPath(path);
				if (resolved != null)
				{
					for (s in PlayState.instance.pythonArray)
						if (s.scriptName == resolved) return s.call(funcName, args);
				}
			}
			#end
			return null;
		});

		// getGlobalFromScript(path, global) — read a variable from another script
		PythonScript.registerFunction("getGlobalFromScript", function(?file:String, ?global:String):Dynamic
		{
			if (file == null || global == null) return null;
			var candidates:Array<String> = [file];
			if (!file.endsWith(".lua") && !file.endsWith(".py"))
			{
				candidates.push(file + ".lua");
				candidates.push(file + ".py");
			}
			#if LUA_ALLOWED
			for (path in candidates)
			{
				var resolved = resolveScriptPath(path);
				if (resolved != null)
					for (s in PlayState.instance.luaArray)
						if (s.scriptName == resolved)
						{
							// Lua host stores globals in its lua state — retrieve via reflection shim
							// Fallback: try PlayState variables for compatibility
							var val:Dynamic = null;
							// Attempt lua-specific get via helper if available
							try
							{
								// Direct Lua state global lookup
								#if LUA_ALLOWED
								if (s.lua != null)
								{
									Lua.getglobal(s.lua, global);
									val = Convert.fromLua(s.lua, -1);
									Lua.pop(s.lua, 1);
									return val;
								}
								#end
							}
							catch (e:Dynamic) {}
						}
			}
			#end
			#if PYTHON_ALLOWED
			for (path in candidates)
			{
				var resolved = resolveScriptPath(path);
				if (resolved != null)
					for (s in PlayState.instance.pythonArray)
						if (s.scriptName == resolved) return s.get(global);
			}
			#end
			return null;
		});

		// setGlobalFromScript(path, global, value)
		PythonScript.registerFunction("setGlobalFromScript", function(file:String, global:String, val:Dynamic):Void
		{
			if (file == null || global == null) return;
			var candidates:Array<String> = [file];
			if (!file.endsWith(".lua") && !file.endsWith(".py"))
			{
				candidates.push(file + ".lua");
				candidates.push(file + ".py");
			}
			#if LUA_ALLOWED
			for (path in candidates)
			{
				var resolved = resolveScriptPath(path);
				if (resolved != null)
					for (s in PlayState.instance.luaArray)
						if (s.scriptName == resolved) s.set(global, val);
			}
			#end
			#if PYTHON_ALLOWED
			for (path in candidates)
			{
				var resolved = resolveScriptPath(path);
				if (resolved != null)
					for (s in PlayState.instance.pythonArray)
						if (s.scriptName == resolved) s.set(global, val);
			}
			#end
		});

		// isRunning(path):Bool
		PythonScript.registerFunction("isRunning", function(file:String):Bool
		{
			if (file == null) return false;
			var candidates:Array<String> = [file];
			if (!file.endsWith(".lua") && !file.endsWith(".py"))
			{
				candidates.push(file + ".lua");
				candidates.push(file + ".py");
			}
			for (path in candidates)
			{
				var resolved = resolveScriptPath(path);
				if (resolved != null)
				{
					#if LUA_ALLOWED
					for (s in PlayState.instance.luaArray)
						if (s.scriptName == resolved) return true;
					#end
					#if PYTHON_ALLOWED
					for (s in PlayState.instance.pythonArray)
						if (s.scriptName == resolved) return true;
					#end
				}
			}
			return false;
		});

		// addLuaScript — load a Lua script at runtime
		PythonScript.registerFunction("addLuaScript", function(file:String, ?ignoreAlreadyRunning:Bool = false):Void
		{
			if (file == null) return;
			var cervix = file;
			if (!cervix.endsWith(".lua")) cervix += ".lua";
			#if LUA_ALLOWED
			PlayState.instance.startLuasOnFolder(cervix);
			#else
			PlayState.instance.pythonArray; // no-op when Lua disabled
			#end
		});

		// addPythonScript — load a Python script at runtime
		PythonScript.registerFunction("addPythonScript", function(file:String, ?ignoreAlreadyRunning:Bool = false):Void
		{
			if (file == null) return;
			var cervix = file;
			if (!cervix.endsWith(".py")) cervix += ".py";
			PlayState.instance.startPythonScriptOnFolder(cervix);
		});

		// Generic addScript — detects extension
		PythonScript.registerFunction("addScript", function(file:String, ?ignoreAlreadyRunning:Bool = false):Void
		{
			if (file == null) return;
			if (file.endsWith(".py"))
				PlayState.instance.startPythonScriptOnFolder(file);
			else if (file.endsWith(".lua"))
			{
				#if LUA_ALLOWED
				PlayState.instance.startLuasOnFolder(file);
				#end
			}
			else
			{
				#if LUA_ALLOWED
				if (PlayState.instance.startLuasOnFolder(file + ".lua")) return;
				#end
				PlayState.instance.startPythonScriptOnFolder(file + ".py");
			}
		});

		// removeLuaScript
		PythonScript.registerFunction("removeLuaScript", function(file:String):Void
		{
			if (file == null) return;
			var cervix = file;
			if (!cervix.endsWith(".lua")) cervix += ".lua";
			var resolved = resolveScriptPath(cervix);
			if (resolved == null) return;
			#if LUA_ALLOWED
			for (s in PlayState.instance.luaArray)
				if (s.scriptName == resolved)
				{
					PlayState.instance.luaArray.remove(s);
					s.stop();
					break;
				}
			#end
		});

		// removePythonScript
		PythonScript.registerFunction("removePythonScript", function(file:String):Void
		{
			if (file == null) return;
			var cervix = file;
			if (!cervix.endsWith(".py")) cervix += ".py";
			var resolved = resolveScriptPath(cervix);
			if (resolved == null) resolved = cervix;
			for (s in PlayState.instance.pythonArray)
				if (s.scriptName == resolved)
				{
					PlayState.instance.pythonArray.remove(s);
					s.stop();
					break;
				}
		});

		// removeScript — generic
		PythonScript.registerFunction("removeScript", function(file:String):Void
		{
			if (file == null) return;
			// Try both
			var luaCandidates = [file];
			if (!file.endsWith(".lua") && !file.endsWith(".py")) luaCandidates.push(file + ".lua");
			else if (file.endsWith(".lua")) luaCandidates = [file];
			for (c in luaCandidates)
			{
				var resolved = resolveScriptPath(c);
				if (resolved != null)
				{
					#if LUA_ALLOWED
					for (s in PlayState.instance.luaArray)
						if (s.scriptName == resolved)
						{
							PlayState.instance.luaArray.remove(s);
							s.stop();
						}
					#end
				}
			}
			var pyCandidates = [file];
			if (!file.endsWith(".lua") && !file.endsWith(".py")) pyCandidates.push(file + ".py");
			else if (file.endsWith(".py")) pyCandidates = [file];
			for (c in pyCandidates)
			{
				var resolved = resolveScriptPath(c);
				if (resolved == null) resolved = c;
				for (s in PlayState.instance.pythonArray)
					if (s.scriptName == resolved)
					{
						PlayState.instance.pythonArray.remove(s);
						s.stop();
					}
			}
		});
	}

	static function resolveScriptPath(cervix:String):Null<String>
	{
		#if MODS_ALLOWED
		if (FileSystem.exists(Paths.modFolders(cervix))) return Paths.modFolders(cervix);
		if (FileSystem.exists(cervix)) return cervix;
		var preload = Paths.getPreloadPath(cervix);
		if (FileSystem.exists(preload)) return preload;
		#else
		#if sys
		var preload = Paths.getPreloadPath(cervix);
		if (OpenFlAssets.exists(preload)) return preload;
		#end
		#end
		return null;
	}
}
