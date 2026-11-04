import debug.PoolStats;

/** Renderer-free contract tests for the pooled gameplay-object accounting (#88).
 *
 * `debug/PoolStats.hx` has no Flixel/OpenFL dependency, so the production module is
 * exercised directly in the interpreter. Run with:
 *
 *     bash tests/haxe/run-pool-stats.sh
 */
class PoolStatsSpec
{
	static function equal<T>(actual:T, expected:T, label:String):Void
	{
		if (actual != expected) throw '$label: expected $expected, got $actual';
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
		testIdle();
		testSpawnAndRelease();
		testSlotIndependence();
		testOutOfRangeSlotsAreIgnored();
		testReset();
		testSteadyStateReuse();
		testSummary();

		trace('PoolStatsSpec passed');
	}

	static function testIdle():Void
	{
		PoolStats.reset();

		equal(PoolStats.totalSpawned(), 0, 'idle spawns');
		equal(PoolStats.totalCreated(), 0, 'idle created');
		equal(PoolStats.totalReused(), 0, 'idle reused');
		near(PoolStats.totalReuseRate(), 0, 'idle reuse rate');
		equal(PoolStats.summary(), 'idle', 'idle summary');
		equal(PoolStats.liveCount(PoolStats.NOTE), 0, 'idle live notes');
	}

	static function testSpawnAndRelease():Void
	{
		PoolStats.reset();

		for (i in 0...3)
			PoolStats.spawn(PoolStats.NOTE, false);
		for (i in 0...7)
			PoolStats.spawn(PoolStats.NOTE, true);

		equal(PoolStats.createdCount(PoolStats.NOTE), 3, 'created notes');
		equal(PoolStats.reusedCount(PoolStats.NOTE), 7, 'reused notes');
		equal(PoolStats.spawnCount(PoolStats.NOTE), 10, 'total note spawns');
		near(PoolStats.reuseRate(PoolStats.NOTE), 0.7, 'note reuse rate');
		equal(PoolStats.liveCount(PoolStats.NOTE), 10, 'live notes before releases');

		for (i in 0...2)
			PoolStats.release(PoolStats.NOTE);
		equal(PoolStats.releasedCount(PoolStats.NOTE), 2, 'released notes');
		equal(PoolStats.liveCount(PoolStats.NOTE), 8, 'live notes after releases');

		// Retiring more sprites than are out of the pool must clamp instead of going
		// negative (a double kill() on one sprite, for example).
		for (i in 0...9)
			PoolStats.release(PoolStats.NOTE);
		equal(PoolStats.releasedCount(PoolStats.NOTE), 11, 'over-released notes');
		equal(PoolStats.liveCount(PoolStats.NOTE), 0, 'clamped live notes');
	}

	static function testSlotIndependence():Void
	{
		PoolStats.reset();

		PoolStats.spawn(PoolStats.SUSTAIN, true);
		PoolStats.spawn(PoolStats.HOLD_SPLASH, false);
		PoolStats.release(PoolStats.HOLD_SPLASH);

		equal(PoolStats.spawnCount(PoolStats.NOTE), 0, 'notes untouched by other slots');
		equal(PoolStats.createdCount(PoolStats.SUSTAIN), 0, 'sustain pool hit is not a miss');
		equal(PoolStats.reusedCount(PoolStats.SUSTAIN), 1, 'sustain pool hit');
		equal(PoolStats.createdCount(PoolStats.HOLD_SPLASH), 1, 'hold splash pool miss');
		equal(PoolStats.liveCount(PoolStats.HOLD_SPLASH), 0, 'hold splash retired');
		equal(PoolStats.totalSpawned(), 2, 'total across slots');
		near(PoolStats.totalReuseRate(), 0.5, 'total reuse rate');
	}

	static function testOutOfRangeSlotsAreIgnored():Void
	{
		PoolStats.reset();

		PoolStats.spawn(-1, true);
		PoolStats.spawn(PoolStats.POOL_COUNT, false);
		PoolStats.release(-1);
		PoolStats.release(1234);

		equal(PoolStats.totalSpawned(), 0, 'out-of-range spawns ignored');
		equal(PoolStats.createdCount(-1), 0, 'negative slot has no counters');
		equal(PoolStats.reusedCount(PoolStats.POOL_COUNT), 0, 'overflow slot has no counters');
		equal(PoolStats.name(-1), 'unknown', 'negative slot name');
		equal(PoolStats.name(PoolStats.POOL_COUNT), 'unknown', 'overflow slot name');
		check(!PoolStats.isValid(-1), 'isValid(-1)');
		check(!PoolStats.isValid(PoolStats.POOL_COUNT), 'isValid(POOL_COUNT)');

		// Every tracked slot must have a distinct, non-empty debug name.
		var seen = new Map<String, Bool>();
		for (i in 0...PoolStats.POOL_COUNT)
		{
			check(PoolStats.isValid(i), 'slot $i must be valid');
			final slotName = PoolStats.name(i);
			check(slotName.length > 0, 'slot $i needs a name');
			check(!seen.exists(slotName), 'duplicate pool name $slotName');
			seen.set(slotName, true);
		}
	}

	static function testReset():Void
	{
		PoolStats.reset();

		for (i in 0...5)
			PoolStats.spawn(PoolStats.POPUP, true);
		PoolStats.release(PoolStats.POPUP);
		check(PoolStats.totalSpawned() > 0, 'counters moved before reset');

		PoolStats.reset();
		equal(PoolStats.totalSpawned(), 0, 'reset clears spawns');
		equal(PoolStats.releasedCount(PoolStats.POPUP), 0, 'reset clears releases');
		equal(PoolStats.summary(), 'idle', 'reset clears the summary');
	}

	/**
	 * Mirrors how the gameplay call sites account for `FlxTypedGroup.recycle()`: a grow
	 * style pool revives a dead member when one is available and only constructs when
	 * every member is live. A song that peaks at eight concurrent notes must therefore
	 * construct eight sprites and reuse the pool for everything after that.
	 */
	static function testSteadyStateReuse():Void
	{
		PoolStats.reset();

		final peak:Int = 8;
		final spawns:Int = 1000;
		var dead:Int = 0;

		// Warm-up: every spawn is a pool miss until the pool reaches the peak.
		for (i in 0...peak)
			PoolStats.spawn(PoolStats.NOTE, false);

		// Steady state: retire the oldest note, then spawn its replacement from the pool.
		for (i in 0...(spawns - peak))
		{
			dead++;
			PoolStats.release(PoolStats.NOTE);
			check(dead > 0, 'a dead member must be available before the pool hit');
			dead--;
			PoolStats.spawn(PoolStats.NOTE, true);
		}

		equal(PoolStats.createdCount(PoolStats.NOTE), peak, 'only the pool warm-up allocates');
		equal(PoolStats.reusedCount(PoolStats.NOTE), spawns - peak, 'everything after warm-up is a pool hit');
		equal(PoolStats.releasedCount(PoolStats.NOTE), spawns - peak, 'every retired note is accounted for');
		equal(PoolStats.liveCount(PoolStats.NOTE), peak, 'live estimate matches the concurrency peak');
		near(PoolStats.reuseRate(PoolStats.NOTE), (spawns - peak) / spawns, 'steady state reuse rate');
	}

	static function testSummary():Void
	{
		PoolStats.reset();

		for (i in 0...2)
			PoolStats.spawn(PoolStats.NOTE, false);
		for (i in 0...8)
			PoolStats.spawn(PoolStats.NOTE, true);
		PoolStats.spawn(PoolStats.SUSTAIN, false);

		final line:String = PoolStats.summary();
		check(line.indexOf('note 2/10 (80%)') >= 0, 'summary must report the note pool: $line');
		check(line.indexOf('sustain 1/1 (0%)') >= 0, 'summary must report the sustain pool: $line');
		check(line.indexOf('popup') < 0, 'summary must skip pools that never spawned: $line');
		check(line.indexOf('crossFade') < 0, 'summary must skip pools that never spawned: $line');
	}
}
