import backend.CameraEffects;
import backend.ClientPrefs;
import backend.PsychCamera;
import flixel.FlxCamera;
import flixel.util.FlxAxes;

class CameraEffectsSpec
{
	static function equal(actual:Dynamic, expected:Dynamic):Void
	{
		if (actual != expected) throw 'Expected $expected, got $actual';
	}

	static function main():Void
	{
		for (camera in [new FlxCamera(), new PsychCamera()])
		{
			var done = function() {};
			for (strength in [0.25, 0.5, 1.0])
			{
				ClientPrefs.cameraFxIntensity = strength;
				CameraEffects.shake(camera, 0.08, 2, done, false, FlxAxes.X);
				equal(camera.intensity, 0.08 * strength);
				equal(camera.duration, 2);
				equal(camera.callback, done);
				equal(camera.force, false);
				equal(camera.axes, FlxAxes.X);
			}
			var calls = camera.calls;
			ClientPrefs.cameraFxIntensity = 0;
			CameraEffects.shake(camera);
			equal(camera.calls, calls);
			ClientPrefs.cameraFxIntensity = 1;
			ClientPrefs.reducedMotion = true;
			CameraEffects.shake(camera);
			equal(camera.calls, calls);
			ClientPrefs.reducedMotion = false;
		}
		var camera = new PsychCamera();
		ClientPrefs.cameraFxIntensity = 0.5;
		camera.shake(0.08);
		equal(camera.intensity, 0.04);
		ClientPrefs.reducedMotion = true;
		camera.shake();
		equal(camera.calls, 1);
		ClientPrefs.reducedMotion = false;
		for (value in [-1.0, 2.0, Math.NaN])
		{
			ClientPrefs.cameraFxIntensity = value;
			equal(CameraEffects.multiplier(), value < 0 ? 0 : 1);
		}
		Sys.println('Camera effects tests passed');
	}
}
