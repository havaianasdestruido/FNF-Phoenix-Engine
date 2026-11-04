package backend;

#if (desktop && !air)
import debug.FrameProfiler;
import openfl.events.KeyboardEvent;
#end
import flixel.FlxGame;
import flixel.FlxState;

class FunkinGame extends FlxGame {
	#if (desktop && !air)
	var fullscreenListener:KeyboardEvent->Void;
	#end

	#if desktop
	// Keep this constructor on AIR so FlxGame still receives startFullscreen;
	// AIR's window/input APIs differ, so only native desktops get the hotkeys.
	public function new(gameWidth:Int, gameHeight:Int, entryState:Class<FlxState>, updateFramerate:Int = 60, drawFramerate:Int = 60, skipSplash:Bool = false, startFullscreen:Bool = false) {
		super(gameWidth, gameHeight, entryState, updateFramerate, drawFramerate, skipSplash, startFullscreen);

		#if (desktop && !air)
		fullscreenListener = function(e:KeyboardEvent) {
			if (e.keyCode == 122) {
				FlxG.fullscreen = !FlxG.fullscreen;
			} else if (e.keyCode == 114) {
				FrameProfiler.toggleOverlay();
				if (Main.fpsVar != null) Main.fpsVar.updateText();
			} else if (e.keyCode == 117) {
				FrameProfiler.exportLog();
			}
		};
		FlxG.stage.addEventListener(KeyboardEvent.KEY_DOWN, fullscreenListener);
		#end
	}
	#end
}
