package backend;

import flixel.FlxCamera;
import flixel.util.FlxAxes;

/** Shared camera-motion policy for plain FlxCamera and PsychCamera callers. */
class CameraEffects
{
	public static function multiplier():Float
	{
		if (ClientPrefs.reducedMotion) return 0;
		var value = ClientPrefs.cameraFxIntensity;
		// Saves and scripts can supply values outside the slider's range.
		if (Math.isNaN(value)) return 1;
		return Math.max(0, Math.min(1, value));
	}

	public static function shake(camera:FlxCamera, intensity:Float = 0.05, duration:Float = 0.5,
		?onComplete:Void->Void, force:Bool = true, ?axes:FlxAxes):Void
	{
		var strength = multiplier();
		if (strength <= 0) return;
		// PsychCamera applies the policy in its override; never multiply twice.
		camera.shake((camera is PsychCamera) ? intensity : intensity * strength,
			duration, onComplete, force, axes);
	}
}
