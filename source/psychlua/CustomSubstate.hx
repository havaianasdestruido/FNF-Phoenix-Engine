package psychlua;

import flixel.FlxObject;
import backend.MusicBeatState;
import backend.MusicBeatSubstate;
import play.PlayState;

class CustomSubstate extends MusicBeatSubstate
{
	public static var name:String = 'unnamed';
	public static var instance:CustomSubstate;

	#if LUA_ALLOWED
	public static function implement(funk:FunkinLua)
	{
		var lua = funk.lua;
		Convert.addCallback(lua, "openCustomSubstate", openCustomSubstate);
		Convert.addCallback(lua, "closeCustomSubstate", closeCustomSubstate);
		Convert.addCallback(lua, "insertToCustomSubstate", insertToCustomSubstate);
		// Switch to a fully scripted MusicBeatState from data/states/<name>.hx
		Convert.addCallback(lua, "switchCustomState", StateScripts.switchState);
		// Open a fully scripted MusicBeatSubstate from data/states/<name>.hx
		Convert.addCallback(lua, "openModSubState", StateScripts.openSubState);
		Convert.addCallback(lua, "customStateExists", StateScripts.exists);
	}
	#end

	#if PYTHON_ALLOWED
	public static function implementPython(python:PythonScript)
	{
		python.set("openCustomSubstate", openCustomSubstate);
		python.set("closeCustomSubstate", closeCustomSubstate);
		python.set("insertToCustomSubstate", insertToCustomSubstate);
		python.set("switchCustomState", StateScripts.switchState);
		python.set("openModSubState", StateScripts.openSubState);
		python.set("customStateExists", StateScripts.exists);
	}
	#end

	#if HSCRIPT_ALLOWED
	public static function implementHScript(hscript:HScript)
	{
		hscript.set("openCustomSubstate", openCustomSubstate);
		hscript.set("closeCustomSubstate", closeCustomSubstate);
		hscript.set("insertToCustomSubstate", insertToCustomSubstate);
		hscript.set("switchCustomState", StateScripts.switchState);
		hscript.set("openModSubState", StateScripts.openSubState);
		hscript.set("customStateExists", StateScripts.exists);
	}
	#end
	
	public static function openCustomSubstate(name:String, ?pauseGame:Bool = false)
	{
		if (pauseGame && PlayState.instance != null)
		{
			FlxG.camera.followLerp = 0;
			PlayState.instance.persistentUpdate = false;
			PlayState.instance.persistentDraw = true;
			PlayState.instance.paused = true;
			if (FlxG.sound.music != null) {
				FlxG.sound.music.pause();
				if (PlayState.instance.vocals != null)
					PlayState.instance.vocals.pause();
			}
		}
		if (FlxG.state != null)
			FlxG.state.openSubState(new CustomSubstate(name));
	}

	public static function closeCustomSubstate()
	{
		if (instance != null)
		{
			instance.close();
			return true;
		}
		return false;
	}

	public static function insertToCustomSubstate(tag:String, ?pos:Int = -1)
	{
		if (instance != null)
		{
			var tagObject:FlxObject = cast (MusicBeatState.getVariables().get(tag), FlxObject);

			if (tagObject != null)
			{
				if (pos < 0) instance.add(tagObject);
				else instance.insert(pos, tagObject);
				return true;
			}
		}
		return false;
	}

	override function create()
	{
		instance = this;
		#if HSCRIPT_ALLOWED
		if (PlayState.instance != null)
		{
			PlayState.instance.setOnHScript('customSubstate', instance);
			PlayState.instance.setOnHScript('customSubstateName', name);
		}
		#end
		callPlayStateHook('onCustomSubstateCreate', [name]);
		super.create();
		callPlayStateHook('onCustomSubstateCreatePost', [name]);
	}

	public function new(name:String)
	{
		CustomSubstate.name = name;
		super();
		this.scriptName = name;
		cameras = [FlxG.cameras.list[FlxG.cameras.list.length - 1]];
	}

	override function update(elapsed:Float)
	{
		callPlayStateHook('onCustomSubstateUpdate', [name, elapsed]);
		super.update(elapsed);
		callPlayStateHook('onCustomSubstateUpdatePost', [name, elapsed]);
	}

	override function destroy()
	{
		callPlayStateHook('onCustomSubstateDestroy', [name]);
		instance = null;
		name = 'unnamed';
		#if HSCRIPT_ALLOWED
		if(PlayState.instance != null)
		{
			PlayState.instance.setOnHScript('customSubstate', null);
			PlayState.instance.setOnHScript('customSubstateName', name);
		}
		#end
		super.destroy();
	}

	static function callPlayStateHook(hook:String, args:Array<Dynamic>):Void
	{
		if (PlayState.instance != null)
			PlayState.instance.callOnLuas(hook, args);
	}
}
