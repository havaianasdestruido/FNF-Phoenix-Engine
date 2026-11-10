import play.helpers.HitTiming;

/**
 * Renderer-free contract tests for the Mic'd Up! Early/Late port.
 *
 * `play/helpers/HitTiming.hx` has no Flixel/OpenFL dependency, so the production
 * module is exercised directly in the interpreter. Run with:
 *
 *     bash tests/haxe/run-hit-timing.sh
 */
class HitTimingSpec
{
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected "$expected", got "$actual"';
	}

	static function near(actual:Float, expected:Float, label:String):Void
	{
		if (Math.abs(actual - expected) > 1e-9) throw '$label: expected $expected, got $actual';
	}

	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	static function main():Void
	{
		testDeadzone();
		testClassification();
		testDeadzonePercent();
		testBadInput();
		testLabels();

		Sys.println('HitTimingSpec: PASS');
	}

	/** 10% of a 180 ms window is a +-18 ms dead zone, like Mic'd Up!. */
	static function testDeadzone():Void
	{
		near(HitTiming.deadzone(180), 18, 'default share');
		near(HitTiming.deadzone(180, 0.25), 45, 'explicit share');
		near(HitTiming.deadzone(0), 0, 'zero window');
		near(HitTiming.deadzone(-100), 0, 'negative window');
		near(HitTiming.deadzone(Math.NaN), 0, 'NaN window');
		// An unusable share falls back to the documented default instead of
		// collapsing the dead zone (which would label every hit).
		near(HitTiming.deadzone(180, 0), 18, 'zero share falls back');
		near(HitTiming.deadzone(180, 1.5), 18, 'out-of-range share falls back');
		near(HitTiming.deadzone(180, Math.NaN), 18, 'NaN share falls back');
	}

	/** `noteDiff` is signed: positive is early, negative is late. */
	static function testClassification():Void
	{
		final window:Float = 180;
		equal(HitTiming.classify(0, window), HitTiming.NONE, 'dead centre');
		equal(HitTiming.classify(18, window), HitTiming.NONE, 'dead-zone edge is neutral');
		equal(HitTiming.classify(-18, window), HitTiming.NONE, 'negative dead-zone edge is neutral');
		equal(HitTiming.classify(18.01, window), HitTiming.EARLY, 'just past the edge, early');
		equal(HitTiming.classify(-18.01, window), HitTiming.LATE, 'just past the edge, late');
		equal(HitTiming.classify(90, window), HitTiming.EARLY, 'half-window early');
		equal(HitTiming.classify(-90, window), HitTiming.LATE, 'half-window late');
		equal(HitTiming.classify(180, window), HitTiming.EARLY, 'full-window early');
		equal(HitTiming.classify(-180, window), HitTiming.LATE, 'full-window late');

		// A window doubling halves the neutral band exactly the same way.
		equal(HitTiming.classify(20, 360), HitTiming.NONE, 'bigger window keeps 20 ms neutral');
		equal(HitTiming.classify(40, 360), HitTiming.EARLY, 'bigger window labels 40 ms early');

		// No usable window means no label, never a wrong one.
		equal(HitTiming.classify(50, 0), HitTiming.NONE, 'zero window is never labelled');
		equal(HitTiming.classify(50, -10), HitTiming.NONE, 'negative window is never labelled');
	}

	/** The option value is a share of the window, clamped to 0..1. */
	static function testDeadzonePercent():Void
	{
		equal(HitTiming.classify(10, 180, 0.25), HitTiming.NONE, 'wide dead zone keeps 10 ms neutral');
		equal(HitTiming.classify(50, 180, 0.25), HitTiming.EARLY, 'wide dead zone labels 50 ms early');
		equal(HitTiming.classify(10, 180, 0.01), HitTiming.EARLY, 'narrow dead zone labels 10 ms early');
	}

	/** NaN differences must not turn into a label. */
	static function testBadInput():Void
	{
		equal(HitTiming.classify(Math.NaN, 180), HitTiming.NONE, 'NaN difference');
		equal(HitTiming.classify(20, Math.NaN), HitTiming.NONE, 'NaN window');
	}

	static function testLabels():Void
	{
		equal(HitTiming.label(HitTiming.EARLY), 'Early', 'early label');
		equal(HitTiming.label(HitTiming.LATE), 'Late', 'late label');
		equal(HitTiming.label(HitTiming.NONE), '', 'no label');
		equal(HitTiming.label('nonsense'), '', 'unknown timing');
		check(HitTiming.isTiming(HitTiming.EARLY), 'early is a timing');
		check(HitTiming.isTiming(HitTiming.LATE), 'late is a timing');
		check(!HitTiming.isTiming(HitTiming.NONE), 'none is not a timing');
		check(!HitTiming.isTiming(null), 'null is not a timing');
	}
}
