package backend;

#if sys
import haxe.io.Bytes;
import lime.app.Application;
import lime.graphics.Image;
import lime.ui.Window;

import backend.RenderPaths;

/**
 * Captures the game window into an image file.
 *
 * Rendering Mode's *Classic* variant uses this once per frame, which is why the
 * folder it writes to has to exist before the first frame is saved. The old
 * version hard-coded `assets\gameRenders` with a Windows-only separator and
 * built the destination by string concatenation (`target + slash + path`), so
 * the per-song folder PlayState asked for was nested twice
 * (`assets/gameRenders/assets/gameRenders/<song>/`) and
 * `FileSystem.createDirectory()` failed on the missing parents. PlayState
 * swallowed that exception, so no folder and no frames were ever produced.
 * `backend.RenderPaths` now handles the path and creates the whole chain.
 */
class Screenshot {
	var x:Int;
	var y:Int;
	var width:Int;
	var height:Int;
	var window:Window = null;
	var image:Image;
	public static var slash:String = #if windows "\\" #else "/" #end;

	public function new(x:Int = -1, y:Int = -1, w:Int = -1, h:Int = -1) {
		if(x < 0) this.x = 0;
		if(y < 0) this.y = 0;
		if(w < 0) width = FlxG.width;
		if(h < 0) height = FlxG.height;

		image = new Image();
	}

	public function setRegion(x:Int, y:Int, w:Int, h:Int) {
		this.x = x;
		this.y = y;
		width = w;
		height = h;

		if(x < 0) this.x = 0;
		if(y < 0) this.y = 0;
		if(w < 0) width = FlxG.width;
		if(h < 0) height = FlxG.height;
	}

	private function getScreen() {
		#if sys
		if(window == null)
			window = Application.current.window;

		image = window.readPixels();
		#end
	}

	private function fixFilename(name:String, lossless:Bool = false):String
	{
		var type:String = lossless ? ".png" : ".jpg";
		if (name.substr(-4) != type)
		{
			name = name + type;
		}
		return name;
	}

	var byteData:Bytes;
	/** Last folder that was created successfully, so Classic Rendering Mode does
	 *  not hit the filesystem once per segment for every single frame. */
	var preparedDirectory:String = null;

	/**
	 * Saves the current window pixels inside `directory`.
	 *
	 * @param directory Folder to write into; defaults to `ClientPrefs.renderPath`.
	 *                  Created (with any missing parent) when it does not exist.
	 * @param name      File name without extension; a timestamped name is
	 *                  generated when empty.
	 * @return whether the file was written.
	 */
	public function save(directory:String = "", name:String = ''):Bool {
		#if sys
		getScreen();

		final target:String = (directory != null && directory.length > 0) ? directory : ClientPrefs.renderPath;
		if (target != preparedDirectory) {
			if (!RenderPaths.ensureDirectory(target)) {
				FlxG.log.warn('Screenshot: could not create the folder "$target", the frame was skipped.');
				return false;
			}
			preparedDirectory = target;
		}

		var fileName:String = name;
		if (fileName == null || fileName.length == 0) {
			var millis = CoolUtil.zeroFill(Std.int(haxe.Timer.stamp() * 1000.0) % 1000, 3);
			fileName = "scr-" + DateTools.format(Date.now(), "%Y-%m-%d_%H-%M-%S-") + millis;
		}

		final path:String = RenderPaths.joinPath(target, fixFilename(fileName, ClientPrefs.lossless));
		byteData = image.encode(ClientPrefs.lossless ? PNG : JPEG, ClientPrefs.quality);
		if (byteData == null) {
			FlxG.log.warn('Screenshot: the frame could not be encoded, it was skipped.');
			return false;
		}

		try {
			File.saveBytes(path, byteData);
			return true;
		} catch (e:Dynamic) {
			FlxG.log.warn('Screenshot: could not write "$path" ($e), the frame was skipped.');
			return false;
		}
		#else
		trace('Cannot save on non-Sys platforms!');
		return false;
		#end
	}
}
#else
class Screenshot {
	public static var slash:String = "/";
	public function new(x:Int = -1, y:Int = -1, w:Int = -1, h:Int = -1) {}
	public function setRegion(x:Int, y:Int, w:Int, h:Int) {}
	public function save(directory:String = "", name:String = ''):Bool {
		trace('Cannot save on non-Sys platforms!');
		return false;
	}
}
#end
