package debug.profiler;

/** Bounded, inclusive wall-clock samples. Heap deltas are observations, not ownership. */
typedef HotspotToken = { var name:String; var started:Float; var heap:Float; }
typedef HotspotEntry = {
  var name:String;
  var calls:Int;
  var totalMs:Float;
  var maxMs:Float;
  var heapNet:Float;
  var heapPositive:Float;
  var heapSamples:Int;
}

class HotspotProfiler
{
  static inline final MAX_NAMES:Int = 256;
  static var entries:Map<String, HotspotEntry> = [];
  static var count:Int = 0;
  static var omitted:Int = 0;
  static var inFrame:Bool = false;

  public static function setInFrame(value:Bool):Void inFrame = value;

  public static function reset():Void
  {
    entries = [];
    count = 0;
    omitted = 0;
    inFrame = false;
  }

  public static function begin(name:String):HotspotToken
  {
    if (!inFrame || !debug.FrameProfiler.enabled) return null;
    return {name: name, started: haxe.Timer.stamp(), heap: debug.FrameProfiler.queryHeapUsedBytes()};
  }

  public static function end(token:HotspotToken):Void
  {
    if (token == null || !inFrame || !debug.FrameProfiler.enabled) return;
    final elapsed = Math.max(0, (haxe.Timer.stamp() - token.started) * 1000);
    final heap = debug.FrameProfiler.queryHeapUsedBytes();
    var entry = entries.get(token.name);
    if (entry == null)
    {
      if (count >= MAX_NAMES) { omitted++; return; }
      entry = {name: token.name, calls: 0, totalMs: 0, maxMs: 0, heapNet: 0, heapPositive: 0, heapSamples: 0};
      entries.set(token.name, entry);
      count++;
    }
    entry.calls++;
    entry.totalMs += elapsed;
    entry.maxMs = Math.max(entry.maxMs, elapsed);
    if (heap >= 0 && token.heap >= 0)
    {
      final delta = heap - token.heap;
      entry.heapNet += delta;
      entry.heapPositive += Math.max(0, delta);
      entry.heapSamples++;
    }
  }

  public static function report(sessionMs:Float):String
  {
    final sorted:Array<HotspotEntry> = [];
    for (entry in entries) sorted.push(entry);
    sorted.sort((a, b) -> a.totalMs < b.totalMs ? 1 : (a.totalMs > b.totalMs ? -1 : 0));
    final out = new StringBuf();
    out.add("\n[HOTSPOTS] INSTRUMENTED CALLS (inclusive wall time; not CPU time)\n");
    out.add("Percent = total wall time / recorded frame-time sum; nested calls overlap and must not be summed.\n");
    out.add("Heap deltas are process managed-heap changes during calls, not retained RAM or allocations; GC, other threads and nested calls can affect them. Native/Lua memory is not included.\n");
    if (sorted.length == 0) out.add("No instrumented calls recorded.\n");
    for (entry in sorted)
    {
      final name = entry.name.split("\n").join(" ").split("\r").join(" ");
      final pct = sessionMs > 0 ? Std.string(Math.round(entry.totalMs / sessionMs * 10000) / 100) + "%" : "N/A";
      final memory = entry.heapSamples > 0 ? 'heap net=${entry.heapNet} B, positive deltas=${entry.heapPositive} B (${entry.heapSamples} samples)' : 'heap=N/A';
      out.add('${name} | calls=${entry.calls} | total=${Math.round(entry.totalMs * 100) / 100} ms | session=${pct} | avg=${Math.round(entry.totalMs / entry.calls * 1000) / 1000} ms | max=${Math.round(entry.maxMs * 1000) / 1000} ms | ${memory}\n');
    }
    if (omitted > 0) out.add('Calls omitted after ${MAX_NAMES} distinct names: ${omitted}\n');
    return out.toString();
  }
}
