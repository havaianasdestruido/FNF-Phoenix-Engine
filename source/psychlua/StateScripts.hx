package psychlua;

import backend.Paths;

using StringTools;

/**
 * Discovers and runs HScript files at `data/states/<StateName>.hx`.
 *
 * Overlay: every `MusicBeatState` / `MusicBeatSubstate` loads scripts named
 * after its class (e.g. `data/states/FreeplayState.hx`).
 * Replacement: `ModState` / `ModSubState` are blank hosts for a named script.
 */
class StateScripts
{
	public static inline var Function_Stop:String = "##PSYCHLUA_FUNCTIONSTOP";
	public static inline var Function_Continue:String = "##PSYCHLUA_FUNCTIONCONTINUE";

	public static final SCRIPT_EXTENSIONS:Array<String> = ['hx', 'hscript', 'hxs'];

	public var scripts:Array<HaxeScript> = [];
	public var scriptName:String = '';
	public var parent:Dynamic = null;

	public function new(?parent:Dynamic, ?scriptName:String)
	{
		this.parent = parent;
		this.scriptName = scriptName != null ? scriptName : '';
	}

	public inline function hasScripts():Bool
		return scripts.length > 0;

	public static function classScriptName(instance:Dynamic):String
	{
		if (instance == null) return '';
		var className:String = Type.getClassName(Type.getClass(instance));
		if (className == null || className.length < 1) return '';
		var dot:Int = className.lastIndexOf('.');
		return dot >= 0 ? className.substr(dot + 1) : className;
	}

	/**
	 * Reject `..`, empty names, and Windows drive prefixes so a script name
	 * cannot escape `data/states/`.
	 */
	public static function sanitizeName(name:String):String
	{
		if (name == null) return '';
		var cleaned:String = name.split('\\').join('/');
		while (cleaned.startsWith('/'))
			cleaned = cleaned.substr(1);
		if (cleaned.indexOf(':') >= 0) return '';

		var parts:Array<String> = cleaned.split('/');
		var out:Array<String> = [];
		for (part in parts)
		{
			if (part == null) continue;
			var piece:String = part.trim();
			if (piece.length < 1 || piece == '.') continue;
			if (piece == '..') return '';
			out.push(piece);
		}
		return out.join('/');
	}

	public static function resolveName(instance:Dynamic, ?overrideName:String):String
	{
		if (overrideName != null && overrideName.length > 0)
			return sanitizeName(overrideName);
		return sanitizeName(classScriptName(instance));
	}

	public static function collectFiles(scriptName:String):Array<String>
	{
		var name:String = sanitizeName(scriptName);
		var files:Array<String> = [];
		if (name.length < 1) return files;

		var folders:Array<String> = [];
		folders.push(Paths.getPreloadPath('data/states/'));
		#if MODS_ALLOWED
		for (mod in Mods.getGlobalMods())
			folders.push(Paths.mods(mod + '/data/states/'));
		folders.push(Paths.mods('data/states/'));
		if (Mods.currentModDirectory != null && Mods.currentModDirectory.length > 0)
			folders.push(Paths.mods(Mods.currentModDirectory + '/data/states/'));
		#end

		for (folder in folders)
		{
			for (ext in SCRIPT_EXTENSIONS)
			{
				var path:String = folder + name + '.' + ext;
				if (fileExists(path) && files.indexOf(path) < 0)
					files.push(path);
			}
		}
		return files;
	}

	public static function exists(scriptName:String):Bool
		return collectFiles(scriptName).length > 0;

	public static function readFile(path:String):String
	{
		if (path == null || path.length < 1) return null;
		#if sys
		try
		{
			if (FileSystem.exists(path)) return File.getContent(path);
		}
		catch (e:Dynamic) {}
		#end
		try
		{
			if (OpenFlAssets.exists(path)) return Assets.getText(path);
		}
		catch (e:Dynamic) {}
		return null;
	}

	static function fileExists(path:String):Bool
	{
		#if sys
		try
		{
			if (FileSystem.exists(path)) return true;
		}
		catch (e:Dynamic) {}
		#end
		try
		{
			if (OpenFlAssets.exists(path)) return true;
		}
		catch (e:Dynamic) {}
		return false;
	}

	public static function loadFor(instance:Dynamic, ?overrideName:String):StateScripts
	{
		var pack = new StateScripts(instance, resolveName(instance, overrideName));
		pack.load();
		return pack;
	}

	public function load():Void
	{
		#if HSCRIPT_ALLOWED
		if (scriptName.length < 1) return;
		for (path in collectFiles(scriptName))
		{
			var script = new HaxeScript(path, parent);
			if (!script.closed)
				scripts.push(script);
		}
		#end
	}

	public function call(name:String, ?args:Array<Dynamic>):Dynamic
	{
		if (scripts.length < 1 || name == null) return Function_Continue;
		if (args == null) args = [];

		var result:Dynamic = Function_Continue;
		for (script in scripts)
		{
			var ret:Dynamic = script.call(name, args);
			if (ret == Function_Stop)
				result = Function_Stop;
			else if (ret != null && ret != Function_Continue)
				result = ret;
		}
		return result;
	}

	public function set(name:String, value:Dynamic):Void
	{
		for (script in scripts)
			script.set(name, value);
	}

	public function destroy():Void
	{
		for (script in scripts)
			script.stop();
		scripts = [];
		parent = null;
	}

	/** Switch to a fully scripted `ModState` named `data/states/<name>.hx`. */
	public static function switchState(name:String, ?data:Dynamic, ?skipTransition:Bool = false):Bool
	{
		var cleaned:String = sanitizeName(name);
		if (cleaned.length < 1) return false;
		if (skipTransition)
		{
			FlxTransitionableState.skipNextTransIn = true;
			FlxTransitionableState.skipNextTransOut = true;
		}
		FlxG.switchState(() -> new states.ModState(cleaned, data));
		return true;
	}

	/** Open a fully scripted `ModSubState` named `data/states/<name>.hx`. */
	public static function openSubState(name:String, ?data:Dynamic):Bool
	{
		var cleaned:String = sanitizeName(name);
		if (cleaned.length < 1 || FlxG.state == null) return false;
		FlxG.state.openSubState(new states.substates.ModSubState(cleaned, data));
		return true;
	}
}
