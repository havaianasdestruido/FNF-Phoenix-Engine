import backend.ScreenDensity;
// ScaleMode / FlxStage / FlxWindow are declared inside the flixel.FlxG
// module, so this one import brings them all into scope.
import flixel.FlxG;

/**
 * Renderer-free contract tests for `backend/ScreenDensity.hx` — the DPI and
 * game-pixel density helpers that HiDPI-aware UI math relies on. With no DPI
 * sources compiled in (no android/lime/flash), `dpi()` resolves to the desktop
 * baseline; `pixelsPerGamePixel()` multiplies the scale-mode factor by the
 * window's backing scale. The production module only needs `flixel.FlxG`, so
 * it runs on the interpreter against the real `PlatformIcons`. Run with:
 *
 *     bash tests/haxe/run-screen-density.sh
 */
class ScreenDensitySpec
{
	/** Asserts reference/value equality with a labelled failure message. */
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	/** Asserts float proximity within 0.001. */
	static function near(actual:Float, expected:Float, label:String):Void
	{
		if (Math.abs(actual - expected) > 0.0001) throw '$label: expected $expected, got $actual';
	}

	/** Asserts a boolean condition with a labelled failure message. */
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	/** Restores the stub module's mutable statics so test order does not matter. */
	static function reset():Void
	{
		FlxG.reset();
		ScreenDensity.invalidate();
	}

	/** Runs every spec section in order and resets the shared state afterwards. */
	static function main():Void
	{
		dpiFallsBackToDesktopBaseline();
		dpiSurvivesInvalidate();
		scaleStaysAtOneAtBaseline();
		pixelsPerGamePixelWithNoScaleInfo();
		pixelsPerGamePixelFromScaleMode();
		pixelsPerGamePixelFromWindowBackingScale();
		pixelsPerGamePixelMultipliesBoth();
		pixelsPerGamePixelRejectsBogusScale();
		dpiCacheIsConsistent();

		Sys.println('ScreenDensitySpec: PASS');
	}

	/** Covers dpi falls back to desktop baseline. */
	static function dpiFallsBackToDesktopBaseline():Void
	{
		reset();
		near(ScreenDensity.dpi(), 96, 'with no density source available, desktop baseline wins');
		near(ScreenDensity.baselineDpi(), 96, 'desktop baseline is 96 dpi');
	}

	/** Covers dpi survives invalidate. */
	static function dpiSurvivesInvalidate():Void
	{
		reset();
		var before = ScreenDensity.dpi();
		ScreenDensity.invalidate();
		near(ScreenDensity.dpi(), before, 'invalidate drops the cache and the next query agrees');
	}

	/** Covers scale stays at one at baseline. */
	static function scaleStaysAtOneAtBaseline():Void
	{
		reset();
		near(ScreenDensity.scale(), 1, 'no upscale at the baseline density');
	}

	/** Covers pixels per game pixel with no scale info. */
	static function pixelsPerGamePixelWithNoScaleInfo():Void
	{
		reset();
		near(ScreenDensity.pixelsPerGamePixel(), 1, 'no scale info means 1:1');
	}

	/** Covers pixels per game pixel from scale mode. */
	static function pixelsPerGamePixelFromScaleMode():Void
	{
		reset();
		FlxG.scaleMode = new ScaleMode(2, 2);
		near(ScreenDensity.pixelsPerGamePixel(), 2, 'the scale-mode factor is used');
		check(FlxG.stage == null, 'no stage in this scenario');
	}

	/** Covers pixels per game pixel from window backing scale. */
	static function pixelsPerGamePixelFromWindowBackingScale():Void
	{
		reset();
		FlxG.stage = new FlxStage(3);
		near(ScreenDensity.pixelsPerGamePixel(), 3, 'the window backing scale is used');
	}

	/** Covers pixels per game pixel multiplies both. */
	static function pixelsPerGamePixelMultipliesBoth():Void
	{
		reset();
		FlxG.scaleMode = new ScaleMode(2, 2);
		FlxG.stage = new FlxStage(4);
		near(ScreenDensity.pixelsPerGamePixel(), 8, 'scale mode and backing scale multiply');
	}

	/** Covers pixels per game pixel rejects bogus scale. */
	static function pixelsPerGamePixelRejectsBogusScale():Void
	{
		reset();
		FlxG.scaleMode = new ScaleMode(0, 0);
		near(ScreenDensity.pixelsPerGamePixel(), 1, 'a zero scale mode is rejected');
		FlxG.scaleMode = new ScaleMode(-2, -2);
		near(ScreenDensity.pixelsPerGamePixel(), 1, 'a negative scale mode is rejected');

		reset();
		FlxG.stage = new FlxStage(0);
		near(ScreenDensity.pixelsPerGamePixel(), 1, 'a zero backing scale is rejected');
		FlxG.stage = new FlxStage(-1);
		near(ScreenDensity.pixelsPerGamePixel(), 1, 'a negative backing scale is rejected');

		// An invalid scale mode leaves the window factor in charge.
		reset();
		FlxG.scaleMode = new ScaleMode(0, 0);
		FlxG.stage = new FlxStage(2);
		near(ScreenDensity.pixelsPerGamePixel(), 2, 'invalid scale mode falls back to the backing scale');
	}

	/** Covers dpi cache is consistent. */
	static function dpiCacheIsConsistent():Void
	{
		reset();
		var first = ScreenDensity.dpi();
		var second = ScreenDensity.dpi();
		near(first, second, 'repeated queries agree');
		ScreenDensity.invalidate();
		near(ScreenDensity.dpi(), first, 'post-invalidate query agrees on this target');
	}
}
