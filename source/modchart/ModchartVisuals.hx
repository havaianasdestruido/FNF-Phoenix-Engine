package modchart;

/**
 * Visual outputs a modifier can contribute. The runtime adapter applies
 * `scaleX`/`scaleY`/`alpha`/`angleZ` to the sprite; `angleX`/`angleY` and
 * `skewX`/`skewY` are carried for parity with FunkinModchart (Flixel sprites
 * have no 3D tilt or skew, so the adapter folds X/Y rotation into the
 * position instead — see `PlayStateModchart`).
 */
class ModchartVisuals
{
	public var scaleX:Float = 1;
	public var scaleY:Float = 1;
	public var alpha:Float = 1;
	public var glow:Float = 0;
	public var angleX:Float = 0;
	public var angleY:Float = 0;
	public var angleZ:Float = 0;
	public var skewX:Float = 0;
	public var skewY:Float = 0;

	public function new()
	{
	}

	public function reset():Void
	{
		scaleX = 1;
		scaleY = 1;
		alpha = 1;
		glow = 0;
		angleX = 0;
		angleY = 0;
		angleZ = 0;
		skewX = 0;
		skewY = 0;
	}
}
