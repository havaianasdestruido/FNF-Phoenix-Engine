import backend.MemoryLedger;
import lime.media.AudioBuffer;
import lime.utils.UInt8Array;
import openfl.display.BitmapData;
import openfl.media.Sound;

/** Dependency-stubbed contract tests for the per-area RAM ledger.
 *
 * `backend/MemoryLedger.hx` is copied next to tiny OpenFL/Lime/backend stubs so
 * the accounting can be executed in the Haxe interpreter without the game
 * haxelibs. Assertions use before/after snapshot deltas so they are robust to
 * the ledger's static (session-lifetime) state. Run with:
 *
 *     bash tests/haxe/run-memory-ledger.sh
 */
class MemoryLedgerSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function near(actual:Float, expected:Float, label:String):Void
  {
    if (Math.abs(actual - expected) > 1e-6) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    final heap:Float = 1000000;
    final rss:Float = 2000000;
    backend.VLog.fakeHeap = heap;

    // 1. A `mods/` path is a mod asset; CPU bytes = w*h*4.
    var before = MemoryLedger.snapshot(heap, rss);
    MemoryLedger.trackImage('images/char.png', 'mods/mymod/images/char.png', new BitmapData(100, 100), false);
    var after = MemoryLedger.snapshot(heap, rss);
    near(after.modAssets.ram - before.modAssets.ram, 40000, 'mod image cpu bytes');
    check(after.modAssets.count - before.modAssets.count == 1, 'mod image count');
    near(after.engineAssets.ram - before.engineAssets.ram, 0, 'engine assets unchanged');

    // 2. An `assets/` path is an engine asset.
    before = after;
    MemoryLedger.trackImage('images/ui.png', 'assets/preload/images/ui.png', new BitmapData(10, 10), false);
    after = MemoryLedger.snapshot(heap, rss);
    near(after.engineAssets.ram - before.engineAssets.ram, 400, 'engine image cpu bytes');

    // 3. GPU-cached images count as VRAM, not CPU RAM.
    before = after;
    MemoryLedger.trackImage('images/bg.png', 'mods/mymod/images/bg.png', new BitmapData(50, 50), true);
    after = MemoryLedger.snapshot(heap, rss);
    near(after.modAssets.ram - before.modAssets.ram, 0, 'gpu image cpu = 0');
    near(after.modAssets.gpu - before.modAssets.gpu, 10000, 'gpu image vram');

    // 4. Sounds contribute decoded PCM bytes.
    before = after;
    final snd = new Sound();
    final buf = new AudioBuffer();
    buf.data = new UInt8Array(88200);
    snd.__buffer = buf;
    MemoryLedger.trackSound('mods/mymod/sounds/voice.ogg', 'mods/mymod/sounds/voice.ogg', snd);
    after = MemoryLedger.snapshot(heap, rss);
    near(after.modAssets.ram - before.modAssets.ram, 88200, 'sound pcm bytes');

    // 5. Untracking frees the bytes.
    before = after;
    MemoryLedger.untrackAsset('images/char.png');
    after = MemoryLedger.snapshot(heap, rss);
    near(before.modAssets.ram - after.modAssets.ram, 40000, 'untrack frees bytes');

    // 6. Mod code = exact Lua + estimated interpreter; unregister frees it.
    before = after;
    final luaId = MemoryLedger.registerCode('scripts/a.lua', 'lua', 'mymod', function():Float return 5000);
    final pyId = MemoryLedger.registerCode('scripts/b.py', 'python', 'mymod', function():Float return 2000);
    after = MemoryLedger.snapshot(heap, rss);
    near(after.modCode.ram - before.modCode.ram, 7000, 'mod code lua + interp');
    near(after.luaBytes - before.luaBytes, 5000, 'lua bytes');
    near(after.interpBytes - before.interpBytes, 2000, 'interp bytes');
    MemoryLedger.unregisterCode(luaId);
    MemoryLedger.unregisterCode(pyId);
    final afterUnreg = MemoryLedger.snapshot(heap, rss);
    near(after.modCode.ram - afterUnreg.modCode.ram, 7000, 'unregister frees code');

    // 7. Interpreter estimate is floored by source size when no heap delta.
    near(MemoryLedger.estimateInterpBytes('abcd', -1, -1), 16, 'interp estimate floor');

    // 8. The formatted lines carry every area and the per-mod breakdown.
    final snap = MemoryLedger.snapshot(heap, rss);
    final compact = MemoryLedger.formatCompact(snap);
    for (key in ['engAssets=', 'modAssets=', 'engCode=', 'modCode=', 'runtime='])
      check(compact.indexOf(key) >= 0, 'compact has $key');
    final detailed = MemoryLedger.formatDetailed(snap);
    check(detailed.indexOf('topMods') >= 0, 'detailed has topMods');
    check(detailed.indexOf('mymod') >= 0, 'detailed names the mod');

    // 9. The five areas are an approximate partition of process RSS.
    final total = snap.engineAssets.ram + snap.modAssets.ram + snap.engineCode.ram + snap.modCode.ram + snap.runtime.ram;
    near(total, rss, 'areas sum to rss');

    Sys.println('MemoryLedgerSpec: all checks passed');
  }
}
