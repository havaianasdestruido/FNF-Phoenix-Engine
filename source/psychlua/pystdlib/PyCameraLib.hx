package psychlua.pystdlib;

import flixel.FlxCamera;
import flixel.FlxG;
import psychlua.PythonScript;
import play.PlayState;
import headers.PsychLua;

// REFACTOR: extracted from psychlua.PythonScript (camera API)
class PyCameraLib
{
	/**
	 * Executes the `register` operation.
	 * @param py Input value for `py`.
	 */
	public static function register(py:PythonScript):Void {
		final game:PlayState = PlayState.instance;
		@:privateAccess {
		// ---------------------------------------------------------------- //
		//                           CAMERA                                 //
		// ---------------------------------------------------------------- //
		PythonScript.registerFunction("cameraSetTarget", function(target:String) {
			switch(target.trim().toLowerCase()) {
				case 'gf' | 'girlfriend':
					game.moveCamera('gf');
				case 'dad' | 'opponent':
					game.moveCamera('dad');
				default:
					game.moveCamera('bf');
			}
		});
		PythonScript.registerFunction("cameraShake", function(camera:String, intensity:Float, duration:Float) {
			LuaUtils.cameraFromString(camera).shake(intensity, duration / PlayState.instance.playbackRate);
		});
		PythonScript.registerFunction("cameraFlash", function(camera:String, color:String, duration:Float, forced:Bool) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			LuaUtils.cameraFromString(camera).flash(colorNum, duration / PlayState.instance.playbackRate, null, forced);
		});
		PythonScript.registerFunction("cameraFade", function(camera:String, color:String, duration:Float, forced:Bool, ?fadeOut:Bool = false) {
			var colorNum:Int = Std.parseInt(color);
			if(!color.startsWith('0x')) colorNum = Std.parseInt('0xff' + color);
			LuaUtils.cameraFromString(camera).fade(colorNum, duration / PlayState.instance.playbackRate, fadeOut, null, forced);
		});
		PythonScript.registerFunction("getMouseX", function(camera:String) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).x;
		});
		PythonScript.registerFunction("getMouseY", function(camera:String) {
			var cam:FlxCamera = LuaUtils.cameraFromString(camera);
			return FlxG.mouse.getScreenPosition(cam).y;
		});
		PythonScript.registerFunction("mouseClicked", function(button:String) {
			var mouseState = FlxG.mouse.justPressed;
			switch(button) {
				case 'middle': mouseState = FlxG.mouse.justPressedMiddle;
				case 'right': mouseState = FlxG.mouse.justPressedRight;
			}
			return mouseState;
		});
		PythonScript.registerFunction("mousePressed", function(button:String) {
			var mouseState = FlxG.mouse.pressed;
			switch(button) {
				case 'middle': mouseState = FlxG.mouse.pressedMiddle;
				case 'right': mouseState = FlxG.mouse.pressedRight;
			}
			return mouseState;
		});
		PythonScript.registerFunction("mouseReleased", function(button:String) {
			var mouseState = FlxG.mouse.justReleased;
			switch(button) {
				case 'middle': mouseState = FlxG.mouse.justReleasedMiddle;
				case 'right': mouseState = FlxG.mouse.justReleasedRight;
			}
			return mouseState;
		});
		}
	}
}
