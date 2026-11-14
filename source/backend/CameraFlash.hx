package backend;

import flixel.FlxCamera;
import flixel.util.FlxColor;

/** Central policy for engine and script camera flashes. */
class CameraFlash
{
	public static function flash(camera:FlxCamera, color:FlxColor, duration:Float, ?onComplete:Void->Void, force:Bool = false):Void
	{
		var intensity = ClientPrefs.flashing ? ClientPrefs.flashIntensity : 0;
		// Saves and imported settings may contain values outside the menu's range.
		if (Math.isNaN(intensity)) intensity = 0;
		intensity = Math.max(0, Math.min(1, intensity));
		if (intensity == 0)
		{
			if (onComplete != null) onComplete();
			return;
		}

		var scaledColor:FlxColor = color;
		scaledColor.alphaFloat = color.alphaFloat * intensity;
		camera.flash(scaledColor, duration * intensity, onComplete, force);
	}
}
