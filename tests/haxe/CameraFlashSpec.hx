import backend.CameraFlash;
import backend.ClientPrefs;
import flixel.FlxCamera;
import flixel.util.FlxColor;

class CameraFlashSpec {
	static function check(value:Bool, label:String):Void {
		if (!value) throw label;
	}
	static function main():Void {
		var camera = new FlxCamera();
		var color:FlxColor = 0x80abcdef;
		var complete = false;
		var callback = function() complete = true;
		CameraFlash.flash(camera, color, 4, callback, true);
		check(camera.calls == 1 && camera.color == color && camera.duration == 4 && camera.force && camera.callback == callback, 'default preserves flash');
		ClientPrefs.flashIntensity = 0.5;
		CameraFlash.flash(camera, color, 4);
		check(camera.calls == 2 && Math.abs(camera.color.alphaFloat - color.alphaFloat * 0.5) < 0.01 && camera.duration == 2, 'scale alpha and duration');
		ClientPrefs.flashing = false;
		CameraFlash.flash(camera, color, 4, callback, true);
		check(camera.calls == 2 && complete, 'disabled suppresses flash and completes');
		ClientPrefs.flashing = true;
		ClientPrefs.flashIntensity = 0;
		CameraFlash.flash(camera, color, 4);
		check(camera.calls == 2, 'zero suppresses flash');
		ClientPrefs.flashIntensity = -1;
		CameraFlash.flash(camera, color, 4);
		check(camera.calls == 2, 'negative clamps to zero');
		ClientPrefs.flashIntensity = 2;
		CameraFlash.flash(camera, color, 4);
		check(camera.calls == 3 && camera.color == color && camera.duration == 4, 'above one clamps to one');
		ClientPrefs.flashIntensity = Math.NaN;
		CameraFlash.flash(camera, color, 4);
		check(camera.calls == 3, 'NaN suppresses flash');
		Sys.println('CameraFlashSpec: PASS');
	}
}
