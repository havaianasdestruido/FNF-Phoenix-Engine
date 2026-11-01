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
import backend.ModSecurity;
import backend.Native;
import objects.Character;
import objects.Alphabet;
import play.PlayState;

/**
 * Standalone HScript file runner. Unlike `psychlua.HScript`, this does not
 * require a Lua parent and can host menu/state scripts at `data/states/`.
 */
class HaxeScript
{
	#if HSCRIPT_ALLOWED
	public static var parser:Parser = new Parser();
	public var interp:Interp;
	#end

	public var scriptName:String = '';
	public var closed:Bool = false;
	public var sandboxed:Bool = false;
	public var securityModName:String = null;
	public var securityAllowlist:Array<String> = [];
	public var parent:Dynamic = null;

	public function new(scriptName:String, ?parent:Dynamic, ?scriptCode:String)
	{
		this.scriptName = scriptName;
		this.parent = parent;

		#if HSCRIPT_ALLOWED
		var source:String = scriptCode;
		if (source == null)
			source = StateScripts.readFile(scriptName);

		var security = ModSecurity.checkScript(scriptName, source, 'haxe');
		sandboxed = security.sandboxed;
		securityModName = security.modName;
		securityAllowlist = security.allowlist;
		ModSecurity.report(security, function(message:String) report(message));
		if (security.findings.length > 0)
		{
			closed = true;
			return;
		}

		interp = new Interp();
		interp.errorHandler = function(err)
		{
			report('$scriptName: $err');
		};
		if (sandboxed)
		{
			interp.importEnabled = false;
			interp.importBlocklist = [
				'sys', 'sys.io', 'sys.net', 'cpp', 'neko', 'hl', 'java',
				'haxe.Http', 'haxe.http', 'lime.net', 'openfl.net'
			];
		}
		seedLibraries();

		if (source == null || source.length < 1)
		{
			report('HaxeScript: empty source for $scriptName');
			closed = true;
			return;
		}

		try
		{
			parser.line = 1;
			parser.allowTypes = true;
			parser.allowJSON = true;
			parser.allowMetadata = true;
			var expr:Expr = parser.parseString(source, scriptName);
			interp.execute(expr);
		}
		catch (e:Exception)
		{
			report('$scriptName: $e');
			closed = true;
		}
		catch (e:Dynamic)
		{
			report('$scriptName: $e');
			closed = true;
		}
		#end
	}

	#if HSCRIPT_ALLOWED
	function seedLibraries():Void
	{
		interp.variables.set('FlxG', flixel.FlxG);
		interp.variables.set('FlxSprite', flixel.FlxSprite);
		interp.variables.set('FlxText', flixel.text.FlxText);
		interp.variables.set('FlxCamera', flixel.FlxCamera);
		interp.variables.set('FlxTimer', flixel.util.FlxTimer);
		interp.variables.set('FlxTween', flixel.tweens.FlxTween);
		interp.variables.set('FlxEase', flixel.tweens.FlxEase);
		// FlxColor is an abstract and cannot be stored as an interpreter value.
		interp.variables.set('FlxColor', {
			TRANSPARENT: 0x00000000,
			WHITE: 0xFFFFFFFF,
			GRAY: 0xFF808080,
			GREY: 0xFF808080,
			BLACK: 0xFF000000,
			RED: 0xFFFF0000,
			GREEN: 0xFF00FF00,
			BLUE: 0xFF0000FF,
			YELLOW: 0xFFFFFF00,
			CYAN: 0xFF00FFFF,
			PINK: 0xFFFF00FF,
			PURPLE: 0xFF800080,
			ORANGE: 0xFFFFA500,
			BROWN: 0xFF8B4513
		});
		interp.variables.set('FlxMath', flixel.math.FlxMath);
		interp.variables.set('FlxTypedGroup', flixel.group.FlxGroup.FlxTypedGroup);
		interp.variables.set('FlxSpriteGroup', flixel.group.FlxSpriteGroup);
		interp.variables.set('PlayState', PlayState);
		interp.variables.set('Paths', Paths);
		interp.variables.set('Conductor', Conductor);
		interp.variables.set('ClientPrefs', ClientPrefs);
		interp.variables.set('Character', Character);
		interp.variables.set('Alphabet', Alphabet);
		interp.variables.set('CustomSubstate', psychlua.CustomSubstate);
		interp.variables.set('ModState', states.ModState);
		interp.variables.set('ModSubState', states.substates.ModSubState);
		interp.variables.set('StateScripts', StateScripts);
		interp.variables.set('MusicBeatState', backend.MusicBeatState);
		interp.variables.set('MusicBeatSubstate', backend.MusicBeatSubstate);
		#if sys
		interp.variables.set('FlxRuntimeShader', flixel.addons.display.FlxRuntimeShader);
		#end
		interp.variables.set('ShaderFilter', openfl.filters.ShaderFilter);
		interp.variables.set('StringTools', StringTools);
		interp.variables.set('Math', Math);
		interp.variables.set('Std', Std);
		interp.variables.set('Type', Type);
		interp.variables.set('Reflect', Reflect);
		interp.variables.set('Native', Native);
		interp.variables.set('Function_Stop', StateScripts.Function_Stop);
		interp.variables.set('Function_Continue', StateScripts.Function_Continue);

		interp.variables.set('state', parent);
		interp.variables.set('game', parent != null ? parent : PlayState.instance);
		interp.scriptObject = parent;

		interp.variables.set('switchCustomState', StateScripts.switchState);
		interp.variables.set('openCustomSubstate', CustomSubstate.openCustomSubstate);
		interp.variables.set('closeCustomSubstate', CustomSubstate.closeCustomSubstate);
		interp.variables.set('openModSubState', StateScripts.openSubState);

		interp.variables.set('debugPrint', function(text:String, ?color:FlxColor = null)
		{
			if (color == null) color = FlxColor.WHITE;
			report(text, color);
		});

		interp.variables.set('setVar', function(name:String, value:Dynamic)
		{
			var vars = variablesMap();
			if (vars != null) vars.set(name, value);
		});
		interp.variables.set('getVar', function(name:String):Dynamic
		{
			var vars = variablesMap();
			if (vars != null && vars.exists(name)) return vars.get(name);
			return null;
		});
		interp.variables.set('removeVar', function(name:String):Bool
		{
			var vars = variablesMap();
			if (vars != null && vars.exists(name))
			{
				vars.remove(name);
				return true;
			}
			return false;
		});

		interp.variables.set('addHaxeLibrary', function(libName:String, ?libPackage:String = '')
		{
			try
			{
				var str:String = '';
				if (libPackage.length > 0) str = libPackage + '.';
				if (!allowClassAccess(str + libName)) return;

				var resolved:Class<Dynamic> = Type.resolveClass(str + libName);
				if (resolved == null) resolved = LuaUtils.resolveClassCompat(libName);
				interp.variables.set(libName, resolved);
			}
			catch (e:Dynamic)
			{
				report('$scriptName addHaxeLibrary: $e');
			}
		});
	}

	function variablesMap():Map<String, Dynamic>
	{
		if (parent != null && parent.variables != null)
			return parent.variables;
		if (PlayState.instance != null)
			return PlayState.instance.variables;
		try
		{
			return backend.MusicBeatState.getVariables();
		}
		catch (e:Dynamic) {}
		return null;
	}
	#end

	public function call(funcToRun:String, ?funcArgs:Array<Dynamic>):Dynamic
	{
		#if HSCRIPT_ALLOWED
		if (closed || interp == null || funcToRun == null) return StateScripts.Function_Continue;
		if (!interp.variables.exists(funcToRun)) return StateScripts.Function_Continue;

		var fn:Dynamic = interp.variables.get(funcToRun);
		if (!Reflect.isFunction(fn)) return StateScripts.Function_Continue;
		if (funcArgs == null) funcArgs = [];
		try
		{
			var result:Dynamic = Reflect.callMethod(null, fn, funcArgs);
			if (result == null) return StateScripts.Function_Continue;
			return result;
		}
		catch (e:Dynamic)
		{
			report('$scriptName:$funcToRun - $e');
			return StateScripts.Function_Continue;
		}
		#else
		return StateScripts.Function_Continue;
		#end
	}

	public function set(name:String, value:Dynamic):Void
	{
		#if HSCRIPT_ALLOWED
		if (closed || interp == null) return;
		interp.variables.set(name, value);
		#end
	}

	public function allowClassAccess(className:String):Bool
	{
		if (!sandboxed || !ModSecurity.isPrivilegedClass(className) || ModSecurity.isRuleAllowed('engine.native-class', securityAllowlist))
			return true;
		report(ModSecurity.formatRuntimeBlock(securityModName, scriptName, 'privileged class reflection: $className'));
		return false;
	}

	public function stop():Void
	{
		closed = true;
		#if HSCRIPT_ALLOWED
		interp = null;
		#end
		parent = null;
	}

	function report(text:String, ?color:FlxColor):Void
	{
		trace(text);
		if (PlayState.instance != null)
			PlayState.instance.addTextToDebug(text, color != null ? color : FlxColor.RED);
	}
}
