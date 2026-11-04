package backend;

/*
 * Phoenix Engine MemoryLedger — per-area RAM attribution for the vlog.
 *
 * The GC only reports a single heap number, which is useless when you want to
 * know *what* is eating RAM on a weak device. The ledger splits process RAM
 * into five areas and keeps a running, per-frame estimate of each:
 *
 *   1. engine assets  — CPU pixels / decoded audio cached from `assets/`;
 *   2. mod assets     — the same, cached from `mods/` (also broken down per mod);
 *   3. engine code    — the engine's own managed-heap footprint (Flixel/OpenFL/
 *                       Lime/Haxe code + live state data), i.e. whatever heap is
 *                       left after assets and mod interpreters are attributed;
 *   3. mod code       — Lua states (exact, via `lua_gc(GCCOUNT)`) plus the
 *                       Python/HScript/HaxeScript interpreters (estimated);
 *   5. runtime        — Haxe/Flixel/etc. reserved stuff outside the managed heap:
 *                       native libraries, the GPU driver, stacks and GC pools
 *                       (RSS minus heap minus Lua), with the GC's reserved-but-
 *                       free pool reported alongside.
 *
 * Accounting model (approximate partition of process RSS):
 *   engineAssets + modAssets            = tracked asset CPU bytes (in the heap);
 *   engineCode                          = max(0, heap - assetCPU - interpBytes);
 *   modCode                             = luaBytes + interpBytes;
 *   runtime                             = max(0, RSS - heap - luaBytes).
 * When RSS is known these sum to ~RSS; GPU texture bytes are reported separately
 * per asset area because VRAM is not process RSS on a discrete GPU.
 *
 * Everything here is fail-safe and cheap enough to run every frame: asset totals
 * are maintained incrementally on cache/clear (never by scanning the cache), Lua
 * memory is an O(1) counter read, and interpreter memory is estimated once at load.
 * Any measurement that a target cannot provide degrades to 0 / "n/a" instead of
 * throwing, so the ledger can never take the game down.
 */

import openfl.display.BitmapData;
import openfl.media.Sound;
import utils.MemoryUtil;
#if cpp
import cpp.vm.Gc;
#elseif hl
import hl.Gc;
#end

/** RAM attributed to one area. `gpu` is VRAM (assets only), `count` tracked items. */
typedef AreaRam =
{
  var ram:Float;
  var gpu:Float;
  var count:Int;
};

/** One mod's share of RAM (assets + code), for the "top mods" breakdown. */
typedef ModRam =
{
  var name:String;
  var ram:Float;
};

/** A full per-area snapshot, produced once per frame by `snapshot()`. */
typedef MemorySnapshot =
{
  var engineAssets:AreaRam;
  var modAssets:AreaRam;
  var engineCode:AreaRam;
  var modCode:AreaRam;
  var runtime:AreaRam;
  var heapBytes:Float;
  var heapReservedBytes:Float;
  var rssBytes:Float;
  var luaBytes:Float;
  var interpBytes:Float;
  var luaCount:Int;
  var interpCount:Int;
  var engineBaselineBytes:Float;
  var topMods:Array<ModRam>;
};

/** A registered mod-code consumer. `getBytes` is re-read every snapshot. */
typedef CodeEntry =
{
  var name:String;
  var kind:String;
  var modName:String;
  var getBytes:Void->Float;
};

/** Internal bookkeeping for one cached asset. */
typedef AssetEntry =
{
  var area:String; // 'engine' | 'mod'
  var kind:String; // 'image' | 'sound'
  var cpu:Float;
  var gpu:Float;
  var modName:String;
};

@:access(openfl.media.Sound)
class MemoryLedger
{
  // -- Tunables ---------------------------------------------------------------

  /** Bytes per pixel for an RGBA32 bitmap / GPU texture. */
  static inline final BYTES_PER_PIXEL:Int = 4;
  /**
   * Rough multiplier from source-text size to interpreter footprint (AST +
   * scopes) for the pure-Haxe Python/HScript runtimes. Only a floor: when a
   * heap delta around the load is available the larger of the two wins.
   */
  static inline final INTERP_SOURCE_FACTOR:Float = 4.0;
  /** How many mods to list in the detailed "top mods" breakdown. */
  static inline final TOP_MODS:Int = 5;
  /** Label for loose shared content directly under `mods/` (no mod folder). */
  public static inline final SHARED_MOD:String = '(shared)';
  /** Label for a consumer whose mod folder could not be determined. */
  public static inline final UNKNOWN_MOD:String = '(unknown)';

  // -- Asset state (incremental totals, never rescanned) ----------------------

  static var assets:Map<String, AssetEntry> = [];
  static var engineAssetCpu:Float = 0.0;
  static var engineAssetGpu:Float = 0.0;
  static var engineAssetCount:Int = 0;
  static var modAssetCpu:Float = 0.0;
  static var modAssetGpu:Float = 0.0;
  static var modAssetCount:Int = 0;
  static var modAssetRam:Map<String, Float> = [];

  // -- Mod-code state ---------------------------------------------------------

  static var codeEntries:Map<Int, CodeEntry> = [];
  static var nextCodeId:Int = 1;

  // -- Engine baseline --------------------------------------------------------

  static var engineBaseline:Float = -1.0;

  // -- Public API: assets -----------------------------------------------------

  /**
   * Records a cached image. `sourcePath` is the resolved file path (used to
   * tell engine vs. mod and to name the mod); `gpuCached` reflects whether
   * `Paths` uploaded it to a GPU texture and freed the CPU pixels.
   *
   * @param key       the `Paths.currentTrackedAssets` cache key
   * @param sourcePath resolved asset path (`mods/...` or `assets/...`)
   * @param bitmap    the cached bitmap (for its dimensions)
   * @param gpuCached true when the CPU pixels were freed in favour of VRAM
   */
  public static function trackImage(key:String, sourcePath:String, bitmap:BitmapData, gpuCached:Bool):Void
  {
    try
    {
      final pixels:Float = (bitmap != null) ? bitmap.width * bitmap.height * BYTES_PER_PIXEL : 0.0;
      final cpu:Float = gpuCached ? 0.0 : pixels;
      final gpu:Float = gpuCached ? pixels : 0.0;
      setAsset('image:' + key, sourcePath, key, 'image', cpu, gpu);
    }
    catch (_:Dynamic) {}
  }

  /**
   * Records a cached sound. Decoded PCM bytes are read from the OpenFL audio
   * buffer when present; otherwise the compressed size is used as a lower bound.
   *
   * @param key        the `Paths.currentTrackedSounds` cache key
   * @param sourcePath resolved asset path (`mods/...` or `assets/...`)
   * @param sound      the cached sound
   */
  public static function trackSound(key:String, sourcePath:String, sound:Sound):Void
  {
    try
    {
      setAsset('sound:' + key, sourcePath, key, 'sound', soundBytes(sound), 0.0);
    }
    catch (_:Dynamic) {}
  }

  /** Forgets a cached asset (image or sound) by its `Paths` cache key. */
  public static function untrackAsset(key:String):Void
  {
    removeAsset('image:' + key);
    removeAsset('sound:' + key);
  }

  // -- Public API: mod code ---------------------------------------------------

  /**
   * Registers a mod-code consumer. `getBytes` is re-read on every snapshot, so
   * Lua can report its live allocator total while interpreters return a fixed
   * estimate. Returns an id to pass to `unregisterCode` when the script stops.
   *
   * @param name     script name (for logs)
   * @param kind     'lua' | 'python' | 'hscript' | 'haxescript'
   * @param modName  owning mod folder, or null when unknown
   * @param getBytes live byte-count provider (must not throw)
   */
  public static function registerCode(name:String, kind:String, modName:String, getBytes:Void->Float):Int
  {
    final id:Int = nextCodeId++;
    codeEntries.set(id, {name: name, kind: kind, modName: (modName == null ? UNKNOWN_MOD : modName), getBytes: getBytes});
    return id;
  }

  /** Unregisters a mod-code consumer by the id returned from `registerCode`. */
  public static function unregisterCode(id:Int):Void
  {
    if (id > 0) codeEntries.remove(id);
  }

  /**
   * Estimates a pure-Haxe interpreter's footprint from its source size and the
   * heap delta observed around its load. The source-size floor keeps the
   * estimate sane when a GC during the load makes the delta negative.
   *
   * @param source      the script source text
   * @param heapBefore  managed heap before the interpreter was built
   * @param heapAfter   managed heap after the script executed
   */
  public static function estimateInterpBytes(source:String, heapBefore:Float, heapAfter:Float):Float
  {
    final sourceBytes:Float = (source != null) ? source.length : 0;
    final floor:Float = sourceBytes * INTERP_SOURCE_FACTOR;
    final delta:Float = (heapBefore >= 0.0 && heapAfter >= 0.0) ? Math.max(0.0, heapAfter - heapBefore) : 0.0;
    return Math.max(floor, delta);
  }

  // -- Public API: baseline ---------------------------------------------------

  /**
   * Captures the engine's boot-time heap footprint (heap minus whatever assets
   * and interpreters already exist). Called lazily on the first snapshot; can
   * also be invoked explicitly right after engine setup for a cleaner baseline.
   */
  public static function captureEngineBaseline():Void
  {
    final heap:Float = VLog.heapUsedBytes();
    if (heap < 0.0) return;
    final interp:Float = sumInterpBytes();
    engineBaseline = Math.max(0.0, heap - (engineAssetCpu + modAssetCpu) - interp);
  }

  // -- Public API: snapshot ---------------------------------------------------

  /**
   * Builds the per-area snapshot for the current frame. Cheap: asset totals are
   * pre-aggregated, Lua is an O(1) counter read per state, and everything else
   * is arithmetic over the heap/RSS numbers the vlog already samples.
   *
   * @param heapBytes managed heap usage (from `VLog.heapUsedBytes()`)
   * @param rssBytes  process RSS, or -1 when the target cannot report it
   */
  public static function snapshot(heapBytes:Float, rssBytes:Float):MemorySnapshot
  {
    if (engineBaseline < 0.0) captureEngineBaseline();

    var luaBytes:Float = 0.0;
    var interpBytes:Float = 0.0;
    var luaCount:Int = 0;
    var interpCount:Int = 0;
    final modTotals:Map<String, Float> = [];
    for (name => ram in modAssetRam)
      modTotals.set(name, ram);
    for (entry in codeEntries)
    {
      final bytes:Float = safeBytes(entry.getBytes);
      if (entry.kind == 'lua')
      {
        luaBytes += bytes;
        luaCount++;
      }
      else
      {
        interpBytes += bytes;
        interpCount++;
      }
      modTotals.set(entry.modName, (modTotals.exists(entry.modName) ? modTotals.get(entry.modName) : 0.0) + bytes);
    }

    final assetCpu:Float = engineAssetCpu + modAssetCpu;
    final engineCodeRam:Float = Math.max(0.0, heapBytes - assetCpu - interpBytes);
    final modCodeRam:Float = luaBytes + interpBytes;
    final runtimeRam:Float = (rssBytes > 0.0 && heapBytes >= 0.0) ? Math.max(0.0, rssBytes - heapBytes - luaBytes) : 0.0;
    final reserved:Float = heapReservedBytes();

    return {
      engineAssets: {ram: engineAssetCpu, gpu: engineAssetGpu, count: engineAssetCount},
      modAssets: {ram: modAssetCpu, gpu: modAssetGpu, count: modAssetCount},
      engineCode: {ram: engineCodeRam, gpu: 0.0, count: 0},
      modCode: {ram: modCodeRam, gpu: 0.0, count: luaCount + interpCount},
      runtime: {ram: runtimeRam, gpu: 0.0, count: 0},
      heapBytes: heapBytes,
      heapReservedBytes: reserved,
      rssBytes: rssBytes,
      luaBytes: luaBytes,
      interpBytes: interpBytes,
      luaCount: luaCount,
      interpCount: interpCount,
      engineBaselineBytes: engineBaseline,
      topMods: topMods(modTotals)
    };
  }

  /** Compact one-line breakdown appended to every per-frame `FRAME` line. */
  public static function formatCompact(snap:MemorySnapshot):String
  {
    return 'ram{engAssets=' + fmt(snap.engineAssets.ram)
      + ' modAssets=' + fmt(snap.modAssets.ram)
      + ' engCode=' + fmt(snap.engineCode.ram)
      + ' modCode=' + fmt(snap.modCode.ram)
      + ' runtime=' + fmt(snap.runtime.ram) + '}';
  }

  /** Rich breakdown for the periodic `RAM` line and state-change snapshots. */
  public static function formatDetailed(snap:MemorySnapshot):String
  {
    final gcFree:Float = (snap.heapReservedBytes > snap.heapBytes && snap.heapBytes >= 0.0) ? snap.heapReservedBytes - snap.heapBytes : -1.0;
    var text:String = 'engineAssets=' + fmt(snap.engineAssets.ram) + ' (gpu ' + fmt(snap.engineAssets.gpu) + ', ' + snap.engineAssets.count + ' items)'
      + ' | modAssets=' + fmt(snap.modAssets.ram) + ' (gpu ' + fmt(snap.modAssets.gpu) + ', ' + snap.modAssets.count + ' items)'
      + ' | engineCode=' + fmt(snap.engineCode.ram) + ' (boot baseline ' + fmt(snap.engineBaselineBytes) + ')'
      + ' | modCode=' + fmt(snap.modCode.ram) + ' (lua ' + fmt(snap.luaBytes) + ' [' + snap.luaCount + ']'
      + ', interp ' + fmt(snap.interpBytes) + ' [' + snap.interpCount + '] est)'
      + ' | runtime=' + fmt(snap.runtime.ram) + ' (gcReserved ' + fmt(gcFree) + ')'
      + ' | heap=' + fmt(snap.heapBytes) + ' rss=' + fmt(snap.rssBytes);
    if (snap.topMods.length > 0)
    {
      final parts:Array<String> = [];
      for (mod in snap.topMods)
        parts.push(mod.name + '=' + fmt(mod.ram));
      text += ' | topMods: ' + parts.join(', ');
    }
    return text;
  }

  // -- Internal: asset bookkeeping --------------------------------------------

  static function setAsset(ledgerKey:String, sourcePath:String, cacheKey:String, kind:String, cpu:Float, gpu:Float):Void
  {
    final origin:{area:String, modName:String} = classify(sourcePath, cacheKey);
    removeAsset(ledgerKey);
    final entry:AssetEntry = {area: origin.area, kind: kind, cpu: cpu, gpu: gpu, modName: origin.modName};
    assets.set(ledgerKey, entry);
    if (origin.area == 'mod')
    {
      modAssetCpu += cpu;
      modAssetGpu += gpu;
      modAssetCount++;
      modAssetRam.set(origin.modName, (modAssetRam.exists(origin.modName) ? modAssetRam.get(origin.modName) : 0.0) + cpu);
    }
    else
    {
      engineAssetCpu += cpu;
      engineAssetGpu += gpu;
      engineAssetCount++;
    }
  }

  static function removeAsset(ledgerKey:String):Void
  {
    final entry:AssetEntry = assets.get(ledgerKey);
    if (entry == null) return;
    assets.remove(ledgerKey);
    if (entry.area == 'mod')
    {
      modAssetCpu = Math.max(0.0, modAssetCpu - entry.cpu);
      modAssetGpu = Math.max(0.0, modAssetGpu - entry.gpu);
      modAssetCount = Std.int(Math.max(0, modAssetCount - 1));
      final left:Float = (modAssetRam.exists(entry.modName) ? modAssetRam.get(entry.modName) : 0.0) - entry.cpu;
      if (left > 0.0) modAssetRam.set(entry.modName, left);
      else modAssetRam.remove(entry.modName);
    }
    else
    {
      engineAssetCpu = Math.max(0.0, engineAssetCpu - entry.cpu);
      engineAssetGpu = Math.max(0.0, engineAssetGpu - entry.gpu);
      engineAssetCount = Std.int(Math.max(0, engineAssetCount - 1));
    }
  }

  /**
   * Splits a resolved asset path into engine vs. mod and names the mod. Any
   * path with a `mods/` segment is a mod asset; the segment after it is the mod
   * folder (or `(shared)` for loose content directly under `mods/`).
   */
  static function classify(sourcePath:String, cacheKey:String):{area:String, modName:String}
  {
    var path:String = (sourcePath != null && sourcePath.length > 0) ? sourcePath : cacheKey;
    if (path == null) return {area: 'engine', modName: null};
    path = path.split('\\').join('/');
    final parts:Array<String> = path.split('/');
    for (i in 0...parts.length)
    {
      if (parts[i] == 'mods')
      {
        final folder:String = (i + 1 < parts.length) ? parts[i + 1] : '';
        if (folder.length < 1) return {area: 'mod', modName: SHARED_MOD};
        return {area: 'mod', modName: isReservedFolder(folder) ? SHARED_MOD : folder};
      }
    }
    return {area: 'engine', modName: null};
  }

  /** True for the loose shared folders under `mods/` (images, data, songs…). */
  static function isReservedFolder(folder:String):Bool
  {
    #if MODS_ALLOWED
    return Mods.ignoreModFolders.contains(folder);
    #else
    return false;
    #end
  }

  /** Decoded PCM bytes of a cached sound, or its compressed size as a floor. */
  static function soundBytes(sound:Sound):Float
  {
    if (sound == null) return 0.0;
    #if !flash
    try
    {
      final buffer:lime.media.AudioBuffer = sound.__buffer;
      if (buffer != null && buffer.data != null) return buffer.data.length;
    }
    catch (_:Dynamic) {}
    #end
    // Streaming / not-yet-decoded / flash: the compressed file size is a safe
    // lower bound on what the sound holds in RAM.
    try
    {
      return (sound.bytesTotal > 0) ? sound.bytesTotal : 0.0;
    }
    catch (_:Dynamic)
      return 0.0;
  }

  // -- Internal: measurement helpers ------------------------------------------

  static function safeBytes(getBytes:Void->Float):Float
  {
    try
    {
      final value:Float = getBytes();
      return (value > 0.0 && !Math.isNaN(value)) ? value : 0.0;
    }
    catch (_:Dynamic)
      return 0.0;
  }

  static function sumInterpBytes():Float
  {
    var total:Float = 0.0;
    for (entry in codeEntries)
      if (entry.kind != 'lua') total += safeBytes(entry.getBytes);
    return total;
  }

  /** GC reserved heap bytes, or -1 when the runtime does not expose it. */
  static function heapReservedBytes():Float
  {
    #if cpp
    try
    {
      return Gc.memInfo64(Gc.MEM_INFO_RESERVED);
    }
    catch (_:Dynamic)
      return -1.0;
    #elseif hl
    try
    {
      final stats = Gc.stats();
      return (stats != null) ? stats.totalAllocated : -1.0;
    }
    catch (_:Dynamic)
      return -1.0;
    #else
    return -1.0;
    #end
  }

  static function topMods(modTotals:Map<String, Float>):Array<ModRam>
  {
    final list:Array<ModRam> = [];
    for (name => ram in modTotals)
      if (ram > 0.0) list.push({name: name, ram: ram});
    list.sort(function(a:ModRam, b:ModRam):Int return (a.ram < b.ram) ? 1 : (a.ram > b.ram) ? -1 : 0);
    return list.slice(0, TOP_MODS);
  }

  static inline function fmt(bytes:Float):String
    return (bytes < 0.0) ? 'n/a' : MemoryUtil.formatMemory(bytes);
}
