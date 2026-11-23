import debug.profiler.HotspotProfiler;
import debug.FrameProfiler;

/**
 * Renderer-free contract tests for `debug/profiler/HotspotProfiler.hx` — the
 * bounded, inclusive wall-clock profiler that the `--profile` mode feeds.
 * Verifies the in-frame gate, the 256-name cap with its omission counter,
 * heap-delta accounting, and the report layout. The production module only
 * touches `debug.FrameProfiler`, so a scripted stand-in replaces the real
 * (Flixel-heavy) one. Run with:
 *
 *     bash tests/haxe/run-hotspot-profiler.sh
 */
class HotspotProfilerSpec
{
	/** Asserts reference/value equality with a labelled failure message. */
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
	}

	/** Asserts a boolean condition with a labelled failure message. */
	static function check(ok:Bool, label:String):Void
	{
		if (!ok) throw label;
	}

	/** Restores the stub module's mutable statics so test order does not matter. */
	static function reset():Void
	{
		HotspotProfiler.reset();
		FrameProfiler.reset();
	}

	/** Runs every spec section in order and resets the shared state afterwards. */
	static function main():Void
	{
		disabledByDefault();
		inFrameGate();
		recordsCalls();
		heapDeltaAccounting();
		heapUnavailableIsNotAccounting();
		reportLayout();
		omissionCap();
		newlinesAreSanitized();

		Sys.println('HotspotProfilerSpec: PASS');
	}

	/** Covers disabled by default. */
	static function disabledByDefault():Void
	{
		reset();
		HotspotProfiler.setInFrame(true);
		var token = HotspotProfiler.begin('nope');
		equal(token, null, 'begin is a no-op while the frame profiler is disabled');
		HotspotProfiler.end(token); // must not crash
		check(HotspotProfiler.report(0).indexOf('nope') < 0, 'nothing is recorded while disabled');
	}

	/** Covers in frame gate. */
	static function inFrameGate():Void
	{
		reset();
		FrameProfiler.enabled = true;

		// Not in a frame: even with the profiler on, nothing begins.
		HotspotProfiler.setInFrame(false);
		equal(HotspotProfiler.begin('outside'), null, 'begin is a no-op outside of a frame');

		// In frame: tokens flow, and end() records them.
		HotspotProfiler.setInFrame(true);
		var token = HotspotProfiler.begin('framed');
		check(token != null, 'begin returns a token inside a frame');
		HotspotProfiler.end(token);
		check(HotspotProfiler.report(1000).indexOf('framed') >= 0, 'the framed call is recorded');

		// Leaving the frame again stops recording.
		HotspotProfiler.setInFrame(false);
		equal(HotspotProfiler.begin('outside-again'), null, 'leaving the frame disables begin again');
	}

	/** Covers records calls. */
	static function recordsCalls():Void
	{
		reset();
		FrameProfiler.enabled = true;
		HotspotProfiler.setInFrame(true);

		var token = HotspotProfiler.begin('tick');
		HotspotProfiler.end(token);
		var report = HotspotProfiler.report(1000);
		check(report.indexOf('tick') >= 0, 'report names the instrumented call');
		check(report.indexOf('calls=1') >= 0, 'report counts the first call');

		var token2 = HotspotProfiler.begin('tick');
		HotspotProfiler.end(token2);
		report = HotspotProfiler.report(1000);
		check(report.indexOf('calls=2') >= 0, 'a second call increments the counter');

		// A null token is tolerated (mixed call sites).
		HotspotProfiler.end(null);
		report = HotspotProfiler.report(1000);
		check(report.indexOf('calls=2') >= 0, 'a null end token records nothing');
	}

	/** Covers heap delta accounting. */
	static function heapDeltaAccounting():Void
	{
		reset();
		FrameProfiler.enabled = true;
		HotspotProfiler.setInFrame(true);
		// Two instrumented calls: one grows the heap by 600, one shrinks it
		// by 500. Net is 100, but only growth counts towards heapPositive.
		FrameProfiler.setHeapScript([1000, 1600, 1000, 500]);

		var first = HotspotProfiler.begin('grow');
		HotspotProfiler.end(first);
		var second = HotspotProfiler.begin('grow');
		HotspotProfiler.end(second);

		var report = HotspotProfiler.report(1000);
		check(report.indexOf('heap net=100 B') >= 0, 'net heap delta sums signed deltas');
		check(report.indexOf('positive deltas=600 B') >= 0, 'positive deltas only count growth');
		check(report.indexOf('(2 samples)') >= 0, 'both end samples were counted');
	}

	/** Covers heap unavailable is not accounting. */
	static function heapUnavailableIsNotAccounting():Void
	{
		reset();
		FrameProfiler.enabled = true;
		HotspotProfiler.setInFrame(true);
		// No scripted heap values: every read reports -1, so the entry must
		// show heap=N/A and no samples.

		var token = HotspotProfiler.begin('quiet');
		HotspotProfiler.end(token);
		var report = HotspotProfiler.report(1000);
		check(report.indexOf('heap=N/A') >= 0, 'unknown heap reads report heap=N/A');
	}

	/** Covers report layout. */
	static function reportLayout():Void
	{
		reset();
		FrameProfiler.enabled = true;
		HotspotProfiler.setInFrame(true);
		var token = HotspotProfiler.begin('layout-check');
		HotspotProfiler.end(token);

		var report = HotspotProfiler.report(0);
		check(report.indexOf('[HOTSPOTS]') >= 0, 'report carries the hotspots header');
		check(report.indexOf('session=N/A') >= 0, 'a zero session time prints N/A, not a fake percentage');
		check(report.indexOf('avg=') >= 0, 'report includes the average column');
		check(report.indexOf('max=') >= 0, 'report includes the max column');

		// Empty report: friendly no-op instead of an empty list.
		HotspotProfiler.reset();
		check(HotspotProfiler.report(1000).indexOf('No instrumented calls recorded.') >= 0,
			'empty report states that nothing was recorded');
	}

	/** Covers omission cap. */
	static function omissionCap():Void
	{
		reset();
		FrameProfiler.enabled = true;
		HotspotProfiler.setInFrame(true);

		// One past the 256-name cap must be omitted and counted, not grow the
		// map without bound.
		for (i in 0...257)
		{
			var token = HotspotProfiler.begin('name-' + i);
			HotspotProfiler.end(token);
		}

		var report = HotspotProfiler.report(1000);
		check(report.indexOf('Calls omitted after 256 distinct names: 1') >= 0,
			'the 257th distinct name is omitted and counted');
		check(report.indexOf('name-0') >= 0, 'names below the cap are recorded');
		check(report.indexOf('name-255') >= 0, 'the 256th distinct name is recorded');
		check(report.indexOf('name-256') < 0, 'the 257th distinct name is not recorded');
	}

	/** Covers newlines are sanitized. */
	static function newlinesAreSanitized():Void
	{
		reset();
		FrameProfiler.enabled = true;
		HotspotProfiler.setInFrame(true);
		var token = HotspotProfiler.begin('bad\nname\rmore');
		HotspotProfiler.end(token);

		var report = HotspotProfiler.report(1000);
		check(report.indexOf('bad name more') >= 0, 'newlines and carriage returns are flattened to spaces');
	}
}
