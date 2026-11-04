package debug;

/**
 * Allocation accounting for the pooled gameplay objects of `play.PlayState`.
 *
 * Notes, sustains, splashes, rating popups and cross fades are all served by
 * `FlxTypedGroup.recycle()` pools, but a pool that silently stops being hit (a
 * `destroy()` where a `kill()` was meant, a `remove(…, true)` on the hot path, a
 * member spliced out of the group) shows up as garbage-collector stutter long
 * before it shows up as a bug. Issue #88: HTML5 has no readable managed heap, so
 * `debug.FrameProfiler.queryHeapUsedBytes()` reports `-1.0` there and the profiler
 * CSV has nothing to say about the note path on web. These counters are that
 * missing signal: they are platform independent, and every read is a plain `Int`.
 *
 * Semantics, per pool slot:
 * - `createdCount`  — a sprite had to be constructed (pool miss / pool growth).
 * - `reusedCount`   — a dead sprite was revived from the pool (pool hit).
 * - `releasedCount` — a sprite left the live set, either `kill()`ed back into the
 *   pool or destroyed by a destructive path (song reset, seek, `KillNotes`).
 * - `liveCount`     — `spawnCount - releasedCount`, i.e. sprites currently out of
 *   the pool. A song that reuses well keeps this bounded at the concurrency peak
 *   and keeps `createdCount` flat after the first few seconds.
 *
 * A steady state of `createdCount == 0` growth with a climbing `reusedCount` is
 * the property the pooling work is meant to guarantee; the counters make it
 * observable in a debug build and assertable in `tests/haxe/PoolStatsSpec.hx`.
 */
class PoolStats
{
  /** Parent note sprites, pooled by `PlayState.notes`. */
  public static final NOTE:Int = 0;

  /** Sustain (hold) pieces, pooled by `PlayState.sustainNotes`. */
  public static final SUSTAIN:Int = 1;

  /** Hit splashes, pooled by `PlayState.grpNoteSplashes`. */
  public static final NOTE_SPLASH:Int = 2;

  /** Hold splashes, pooled by `PlayState.grpHoldSplashes`. */
  public static final HOLD_SPLASH:Int = 3;

  /** Rating/combo popups, pooled by `PlayState.popUpGroup`. */
  public static final POPUP:Int = 4;

  /** Opponent cross fade ghosts, pooled by the `grp*CrossFade` groups. */
  public static final CROSS_FADE:Int = 5;

  /** Number of tracked pool slots. */
  public static final POOL_COUNT:Int = 6;

  /** Fixed slot order so reports, CSVs and tests stay stable. */
  static final names:Array<String> = ['note', 'sustain', 'noteSplash', 'holdSplash', 'popup', 'crossFade'];

  static final created:Array<Int> = [0, 0, 0, 0, 0, 0];
  static final reused:Array<Int> = [0, 0, 0, 0, 0, 0];
  static final released:Array<Int> = [0, 0, 0, 0, 0, 0];

  /**
   * Records one spawn served by a pool.
   *
   * @param pool      one of the slot constants of this class.
   * @param fromPool  `true` when the sprite was revived from the pool, `false`
   *                  when it had to be constructed. Callers derive this from the
   *                  group size: `recycle()` grows the group only on a miss.
   */
  public static inline function spawn(pool:Int, fromPool:Bool):Void
  {
    if (pool < 0 || pool >= POOL_COUNT)
      return;
    if (fromPool)
      reused[pool]++;
    else
      created[pool]++;
  }

  /**
   * Records one sprite leaving the live set (killed back into the pool or
   * destroyed by a destructive path).
   *
   * @param pool one of the slot constants of this class.
   */
  public static inline function release(pool:Int):Void
  {
    if (pool < 0 || pool >= POOL_COUNT)
      return;
    released[pool]++;
  }

  /** Clears every counter; called when a song starts so numbers are per play. */
  public static function reset():Void
  {
    for (i in 0...POOL_COUNT)
    {
      created[i] = 0;
      reused[i] = 0;
      released[i] = 0;
    }
  }

  /** Whether `pool` is a tracked slot. */
  public static inline function isValid(pool:Int):Bool
  {
    return pool >= 0 && pool < POOL_COUNT;
  }

  /** Debug name of a pool slot (`"unknown"` when out of range). */
  public static function name(pool:Int):String
  {
    return isValid(pool) ? names[pool] : 'unknown';
  }

  /** Sprites that had to be constructed for this pool. */
  public static inline function createdCount(pool:Int):Int
  {
    return isValid(pool) ? created[pool] : 0;
  }

  /** Sprites this pool served by reviving a dead member. */
  public static inline function reusedCount(pool:Int):Int
  {
    return isValid(pool) ? reused[pool] : 0;
  }

  /** Sprites that left the live set for this pool. */
  public static inline function releasedCount(pool:Int):Int
  {
    return isValid(pool) ? released[pool] : 0;
  }

  /** Total spawns served by this pool, from the pool or freshly built. */
  public static inline function spawnCount(pool:Int):Int
  {
    return createdCount(pool) + reusedCount(pool);
  }

  /**
   * Sprites currently out of the pool, never negative. Counts spawns rather than
   * constructions: a pooled sprite is constructed once but retired and revived many
   * times, so only the spawn/release difference tracks live occupancy.
   */
  public static inline function liveCount(pool:Int):Int
  {
    final live:Int = spawnCount(pool) - releasedCount(pool);
    return live > 0 ? live : 0;
  }

  /**
   * Share of spawns served from the pool, `0..1` (`0` when nothing spawned yet).
   */
  public static function reuseRate(pool:Int):Float
  {
    final total:Int = spawnCount(pool);
    return total > 0 ? reusedCount(pool) / total : 0;
  }

  /** Sprites constructed across every tracked pool. */
  public static function totalCreated():Int
  {
    var total:Int = 0;
    for (i in 0...POOL_COUNT)
      total += created[i];
    return total;
  }

  /** Spawns served from a pool across every tracked pool. */
  public static function totalReused():Int
  {
    var total:Int = 0;
    for (i in 0...POOL_COUNT)
      total += reused[i];
    return total;
  }

  /** Every spawn served across every tracked pool. */
  public static function totalSpawned():Int
  {
    return totalCreated() + totalReused();
  }

  /** Share of all spawns served from a pool, `0..1`. */
  public static function totalReuseRate():Float
  {
    final total:Int = totalSpawned();
    return total > 0 ? totalReused() / total : 0;
  }

  /**
   * One line per pool that actually spawned something, e.g.
   * `note 12/140 (91%) sustain 8/60 (86%)`. Built at most once a second by the
   * FPS overlay, so the concatenations are not on a hot path.
   */
  public static function summary():String
  {
    var out:String = '';
    for (i in 0...POOL_COUNT)
    {
      final total:Int = spawnCount(i);
      if (total <= 0)
        continue;
      if (out.length > 0)
        out += ' ';
      out += names[i] + ' ' + created[i] + '/' + total + ' (' + Std.int(Math.round(reuseRate(i) * 100)) + '%)';
    }
    return out.length > 0 ? out : 'idle';
  }
}
