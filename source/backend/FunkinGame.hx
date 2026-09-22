package backend;

import openfl.events.KeyboardEvent;
import flixel.FlxGame;
import flixel.FlxState;

class FunkinGame extends FlxGame {
	#if desktop
	var fullscreenListener:KeyboardEvent->Void;
	
	/**
	 * Executes the `new` operation.
	 * @param gameWidth Input value for `gameWidth`.
	 * @param gameHeight Input value for `gameHeight`.
	 * @param entryState Input value for `entryState`.
	 * @param updateFramerate Input value for `updateFramerate`.
	 * @param drawFramerate Input value for `drawFramerate`.
	 * @param skipSplash Input value for `skipSplash`.
	 * @param startFullscreen Input value for `startFullscreen`.
	 */
	public function new(gameWidth:Int, gameHeight:Int, entryState:Class<FlxState>, updateFramerate:Int = 60, drawFramerate:Int = 60, skipSplash:Bool = false, startFullscreen:Bool = false) {
		super(gameWidth, gameHeight, entryState, updateFramerate, drawFramerate, skipSplash, startFullscreen);
		
		fullscreenListener = function(e:KeyboardEvent) {
			if (e.keyCode == 122) {
				FlxG.fullscreen = !FlxG.fullscreen;
			}
		};
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, fullscreenListener);
	}
	#end
}