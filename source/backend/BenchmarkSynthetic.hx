package backend;

import backend.BenchmarkChart;
import backend.Native;
import backend.PhoenixVersion;

/**
 * Pure-Haxe, no-GPU micro-benchmark suite — the non-visual half of the
 * expanded benchmark. Where `BenchmarkChart` measures the real gameplay
 * pipeline (stage, notes, HUD, camera), this measures the engine's raw CPU
 * and memory substrate so a device that stutters can be triaged as
 * \"GPU-bound\" vs \"CPU-bound\" vs \"allocation/GC-bound\" without waiting 60 s.
 *
 * Each sample runs a tight loop with `haxe.Timer.stamp()` bracketing; the
 * counts are chosen to be ~10–80 ms per sample on a mid-range desktop so the
 * whole suite finishes in ~1–2 s even on a low-end phone. No Flixel, no
 * OpenFL, no asset I/O — the only warm-up is one throwaway iteration to
 * fault the interpreter/JIT.
 *
 * The shape is deliberately renderer-free and import-free enough to be
 * re-used by `tests/haxe/BenchmarkSpec.hx` — keep it free of `FlxG`, `Paths`
 * and `PlayState` for the same reason `BenchmarkChart` stays import-free.
 *
 * Report text is assembled in `formatReport()` to the same plain-text shape as
 * `Benchmark.reportText()` so the results screen can paste one block.
 * Scoring: each sample's `score` is `1000 / avgMs` clamped, then blended into
 * an overall `score` (geometric mean) so a single spike cannot inflate the
 * headline.
 */
class BenchmarkSynthetic
{
  /** One measured loop. */
  public static inline var DEFAULT_ITERATIONS:Int = 1;

  public static function run():SyntheticResult
  {
    final stamp:Date = Date.now();
    final stampStr:String = stamp.toString();

    final samples:Array<SyntheticSample> = [];

    // Warm the interpreter/JIT with a throwaway tick of the cheapest sample.
    try
    {
      sampleMath(200);
    }
    catch (_:Dynamic) {}

    samples.push(runSample('JSON Parse', 120, function() sampleJsonParse(1)));
    samples.push(runSample('Chart Build', 200, function() sampleChartBuild(1)));
    samples.push(runSample('Sort (10k)', 80, function() sampleSort(1)));
    samples.push(runSample('Path Ops', 2000, function() samplePathOps(1)));
    samples.push(runSample('BPM Math', 5000, function() sampleBpmMath(1)));
    samples.push(runSample('String Ops', 1500, function() sampleStringOps(1)));
    samples.push(runSample('Alloc/GC', 600, function() sampleAlloc(1)));
    samples.push(runSample('Trig/Math', 1200, function() sampleTrig(1)));
    samples.push(runSample('Map/Hash', 1000, function() sampleMapOps(1)));

    var totalMs:Float = 0.0;
    for (s in samples) totalMs += s.totalMs;

    var product:Float = 1.0;
    var valid:Int = 0;
    for (s in samples)
      if (s.score > 0)
      {
        product *= s.score;
        valid++;
      }
    final overall:Float = valid > 0 ? Math.pow(product, 1.0 / valid) : 0.0;

    return {
      timestamp: stampStr,
      totalMs: totalMs,
      samples: samples,
      score: overall
    };
  }

  static function runSample(name:String, iters:Int, fn:Void->Void):SyntheticSample
  {
    // One throwaway to warm caches.
    try fn() catch (_:Dynamic) {}

    final t0:Float = haxe.Timer.stamp();
    for (_ in 0...iters)
      fn();
    final t1:Float = haxe.Timer.stamp();
    final totalMs:Float = (t1 - t0) * 1000.0;
    final avgMs:Float = iters > 0 ? totalMs / iters : 0.0;
    final ops:Float = avgMs > 0 ? 1000.0 / avgMs : 0.0;
    // Score: ops scaled to ~100 for a 10 ms average, clamped.
    final rawScore:Float = avgMs > 0 ? (1000.0 / avgMs) : 0.0;
    final score:Float = Math.min(9999, Math.max(0, rawScore));

    return {
      name: name,
      iterations: iters,
      totalMs: totalMs,
      avgMs: avgMs,
      opsPerSec: ops,
      score: score
    };
  }

  // ---- Samples -------------------------------------------------------------

  /**
   * Psych-style chart JSON stringify/parse round-trip: the cost `data.Song`
   * pays on every retry.
   */
  static function sampleJsonParse(_iters:Int):Void
  {
    final chart:Dynamic = BenchmarkChart.build();
    final json:String = haxe.Json.stringify(chart);
    final parsed:Dynamic = haxe.Json.parse(json);
    // Touch a field so DCE cannot drop the parse.
    final _ = Reflect.field(parsed, 'song');
  }

  /** Chart generator throughput: the cost behind the 60 s fixed chart. */
  static function sampleChartBuild(_iters:Int):Void
  {
    final chart:Dynamic = BenchmarkChart.build();
    final sections:Array<Dynamic> = cast chart.notes;
    var n:Int = 0;
    for (s in sections) n += (cast s.sectionNotes : Array<Dynamic>).length;
    if (n == 0) throw 'empty chart';
  }

  /** Numeric sort of note timestamps — `FlxSort`/`Array.sort` hot path. */
  static function sampleSort(_iters:Int):Void
  {
    final N:Int = 10000;
    final arr:Array<Float> = [];
    var seed:Array<Int> = [0x12345678];
    for (_ in 0...N) arr.push((nextRand(seed) % 60000) + (nextRand(seed) % 1000) / 1000.0);
    arr.sort(function(a:Float, b:Float):Int return a < b ? -1 : a > b ? 1 : 0);
    if (arr[0] > arr[N - 1]) throw 'unsorted';
  }

  /** Path string joins/splits — `Paths`/`CoolUtil` hot path. */
  static function samplePathOps(_iters:Int):Void
  {
    final parts:Array<String> = ['mods', 'test-mod', 'images', 'characters', 'bf', 'atlas.png'];
    final joined:String = parts.join('/');
    final split:Array<String> = joined.split('/');
    final lower:String = joined.toLowerCase();
    final dot:Int = lower.indexOf('.');
    if (split.length != 6 || dot == -1) throw 'path mismatch';
  }

  /** BPM/Conductor step/beat math — per-frame timing hot path. */
  static function sampleBpmMath(_iters:Int):Void
  {
    final bpm:Float = 120.0;
    final crochet:Float = (60.0 / bpm) * 1000.0; // 500 ms per beat
    final stepCrochet:Float = crochet / 4.0; // 125 ms per step
    var pos:Float = 0.0;
    var beat:Int = 0;
    var step:Int = 0;
    for (i in 0...500)
    {
      pos += stepCrochet;
      beat = Std.int(pos / crochet);
      step = Std.int(pos / stepCrochet);
      if (beat < 0 || step < 0) throw 'bpm math';
    }
    if (pos <= 0) throw 'bpm pos';
  }

  /** String alloc/concat/replace — dialogue, file-path and log hot path. */
  static function sampleStringOps(_iters:Int):Void
  {
    var s:String = 'phoenix-benchmark-visual-logic-synthetic-suite';
    for (_ in 0...80)
    {
      s = s.split('-').join('_');
      s = s.split('_').join('-');
      s = s.toUpperCase().toLowerCase();
    }
    if (s.length == 0) throw 'string empty';
  }

  /** Allocate and copy arrays of note-like objects — GC pressure proxy. */
  static function sampleAlloc(_iters:Int):Void
  {
    var arr:Array<Dynamic> = [];
    for (i in 0...400)
      arr.push({time: i * 125.0, lane: i % 8, sus: 0.0, type: 0});
    var copy:Array<Dynamic> = arr.copy();
    copy.sort(function(a:Dynamic, b:Dynamic):Int return a.time < b.time ? -1 : 1);
    if (copy.length != 400 || copy[0].time != 0) throw 'alloc mismatch';
  }

  /** Trig/sqrt/pow — modchart `Modifier` and camera lerp hot path. */
  static function sampleTrig(_iters:Int):Void
  {
    var acc:Float = 0.0;
    for (i in 0...600)
    {
      final rad:Float = i * 0.0174533; // ~1 deg steps
      acc += Math.sin(rad) + Math.cos(rad) + Math.sqrt(i + 1) + Math.pow(1.001, i % 100);
    }
    if (!Math.isFinite(acc)) throw 'trig non-finite';
  }

  /** Map insert/lookup/remove — asset-cache and mod-lookup proxy. */
  static function sampleMapOps(_iters:Int):Void
  {
    final map:Map<String, Int> = new Map();
    for (i in 0...500)
      map.set('asset_' + i, i);
    var sum:Int = 0;
    for (k in map.keys()) sum += map.get(k);
    for (i in 0...250) map.remove('asset_' + i);
    if (sum <= 0) throw 'map sum';
  }

  // ---- Formatting ----------------------------------------------------------

  public static function formatReport(result:SyntheticResult):String
  {
    final out:Array<String> = [];
    final info = Native.getSystemInfo();
    out.push('Phoenix Engine - Synthetic Benchmark (non-visual)');
    out.push('Date: ' + result.timestamp);
    out.push('Run: 9 micro-benchmarks on the engine core (no stage, no audio)');
    out.push('');
    out.push('[SYNTHETIC RESULTS]');
    out.push('Total time      : ' + fmt(result.totalMs, 2) + ' ms for ' + result.samples.length + ' samples');
    out.push('Overall score   : ' + fmt(result.score, 1) + '  (higher is faster; geometric mean of sample scores)');
    out.push('');
    out.push(pad('Sample', 16) + pad('Iters', 8) + pad('Total ms', 12) + pad('Avg ms', 10) + 'Score');
    out.push(repeat('-', 62));
    for (s in result.samples)
    {
      final line:String = pad(s.name, 16) + pad(Std.string(s.iterations), 8) + pad(fmt(s.totalMs, 2), 12) + pad(fmt(s.avgMs, 3), 10) + fmt(s.score, 1);
      out.push(line);
    }
    out.push('');
    out.push('[DEVICE (at synthetic run)]');
    out.push('OS                : ' + trimPair(info.osName, info.osVersion));
    out.push('CPU               : ' + info.cpuModel);
    out.push('CPU cores         : ' + debug.system.SystemInfo.logicalCPUCount());
    out.push('Total RAM         : ' + byteText(debug.system.SystemInfo.totalPhysicalMemory()));
    out.push('Engine            : Phoenix v' + PhoenixVersion.current);
    out.push('');
    out.push('[NOTE]');
    out.push('Scores compare on this device only (same binary, same power state).');
    out.push('A low JSON/Sort score points at CPU; a low Alloc/GC spike points at heap.');
    return out.join('\n');
  }

  public static function oneLineSummary(result:SyntheticResult):String
  {
    if (result == null || result.samples.length == 0) return 'No synthetic data.';
    return 'Score ' + fmt(result.score, 1) + '  |  ' + fmt(result.totalMs, 1) + ' ms total  |  slowest ' + slowestName(result) + ' ' + fmt(slowestAvg(result), 3) + ' ms';
  }

  static function slowestName(result:SyntheticResult):String
  {
    var worst:SyntheticSample = result.samples[0];
    for (s in result.samples) if (s.avgMs > worst.avgMs) worst = s;
    return worst.name;
  }

  static function slowestAvg(result:SyntheticResult):Float
  {
    var worst:Float = 0.0;
    for (s in result.samples) if (s.avgMs > worst) worst = s.avgMs;
    return worst;
  }

  // ---- Small helpers (mirrored in Benchmark.reportText so both reports feel same) ----

  static function nextRand(state:Array<Int>):Int
  {
    state[0] = state[0] * 1664525 + 1013904223;
    return state[0] >>> 1;
  }

  static function fmt(value:Float, decimals:Int):String
  {
    if (Math.isNaN(value) || !Math.isFinite(value)) return 'N/A';
    final mul:Float = Math.pow(10, decimals);
    return Std.string(Math.round(value * mul) / mul);
  }

  static function trimPair(a:String, b:String):String
  {
    final left:String = a == null ? '' : a;
    final right:String = b == null ? '' : b;
    if (left.length == 0) return right.length == 0 ? Native.UNKNOWN : right;
    return right.length == 0 ? left : left + ' ' + right;
  }

  static function byteText(bytes:Float):String
  {
    if (bytes <= 0 || Math.isNaN(bytes)) return 'unavailable';
    if (bytes >= 1024.0 * 1024.0 * 1024.0) return fmt(bytes / (1024.0 * 1024.0 * 1024.0), 1) + ' GB';
    return fmt(bytes / (1024.0 * 1024.0), 0) + ' MB';
  }

  static function pad(s:String, width:Int):String
  {
    if (s.length >= width) return s.substr(0, width);
    var out:String = s;
    while (out.length < width) out += ' ';
    return out;
  }

  static function repeat(ch:String, count:Int):String
  {
    var b:StringBuf = new StringBuf();
    for (_ in 0...count) b.add(ch);
    return b.toString();
  }
}

typedef SyntheticSample =
{
  var name:String;
  var iterations:Int;
  var totalMs:Float;
  var avgMs:Float;
  var opsPerSec:Float;
  var score:Float;
}

typedef SyntheticResult =
{
  var timestamp:String;
  var totalMs:Float;
  var samples:Array<SyntheticSample>;
  var score:Float;
}
