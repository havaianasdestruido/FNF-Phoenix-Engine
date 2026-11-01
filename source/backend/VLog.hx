package backend;

/*
 * Phoenix Engine VLog — the "everything" log.
 *
 * Every build records a running, aggressively verbose session log at
 * `vlog/log.txt` next to the working directory:
 *
 *  - desktop builds: `vlog/log.txt` next to the executable (same place as
 *    `crash/` and `mods/`);
 *  - Android: the app's external files directory, which is exactly the
 *    directory the SAF "VLogs" root of `PhoenixDocumentsProvider` exposes
 *    (the same mechanism that publishes `mods/` and `crash/`);
 *  - web/flash: no writable filesystem, so the log is kept in memory and can
 *    be retrieved with `exportText()` / downloaded with `download()`.
 *
 * What goes in there (aggressively):
 *  - a session header/footer: engine version, target, working directory,
 *    launch arguments, full hardware report, duration, frame totals,
 *    lag-spike counts, peak heap/RSS;
 *  - one line per frame: FPS, frametime, work time, update count, draw
 *    calls, managed heap, process RSS, current state;
 *  - lag spikes: any frame over max(2x budget, 25 ms) gets a dedicated
 *    LAG SPIKE line; over 100 ms it is called out as EXTREME;
 *  - every `trace()` in the engine and in the scripting runtimes — Lua
 *    (`luaTrace`), Python (`pyTrace`) and HScript (the interpreter's built-in
 *    `trace`) — captured through `haxe.Log.traceHook` and tagged with the
 *    originating language;
 *  - RAM asset-cache events: images cached (CPU bitmap vs GPU texture),
 *    sounds decoded, note skins, `clearStoredMemory` / `clearUnusedMemory`
 *    results and every explicit GC/compact with heap before/after;
 *  - state changes and uncaught errors (crashes), mirrored from
 *    `CrashHandler` so the live log carries the same context as `crash/`.
 *
 * The writer is fail-safe: any filesystem problem disables vlog writes for
 * the session (with a console notice) instead of taking the game down, and
 * lines are buffered in memory and flushed at most every 250 ms so a crash
 * never loses more than a quarter second of log.
 */

import flixel.FlxG;
import haxe.PosInfos;
#if sys
import Sys;
import sys.FileSystem;
import sys.io.File;
#end
#if web
import openfl.utils.File as OpenFlFile;
#end
import lime.app.Application;
import utils.MemoryUtil;

class VLog
{
  // -- File layout -----------------------------------------------------------

  /** Directory the log lives in (relative to the working directory). */
  public static inline var DIR:String = "vlog";
  /** The log file every build writes. */
  public static inline var FILE:String = "vlog/log.txt";

  /** Rotate the live log once it grows past this size (10 MiB). */
  static inline final MAX_LOG_BYTES:Int = 10 * 1024 * 1024;
  /** Rotated backups kept: `log.1.txt`, `log.2.txt` (oldest is dropped). */
  static inline final MAX_ROTATED:Int = 2;
  /** Flush the in-memory buffer once it holds at least this many characters… */
  static inline final FLUSH_CHARS:Int = 32768;
  /** …or at least this often, so a crash loses at most ~¼ s of log. */
  static inline final FLUSH_INTERVAL_MS:Float = 250.0;
  /** A frame slower than max(2x budget, 25 ms) is logged as a lag spike. */
  static inline final LAG_SPIKE_MIN_MS:Float = 25.0;
  /** …and anything over this is called out as an extreme lag spike. */
  static inline final LAG_EXTREME_MS:Float = 100.0;
  /** Web/flash builds cannot write files: cap the in-memory log instead. */
  static inline final MAX_WEB_CHARS:Int = 2 * 1024 * 1024;
  /** RSS is a syscall on desktop; sample at most once per N frames. */
  static inline final RSS_EVERY_N_FRAMES:Int = 60;

  // -- Session state ---------------------------------------------------------

  static var initialized:Bool = false;
  static var fileReady:Bool = false;
  static var flushFailed:Bool = false;

  static var buffer:StringBuf = new StringBuf();
  static var lastFlushMs:Float = 0.0;
  static var flushCount:Int = 0;

  static var frameIndex:Int = 0;
  static var targetMs:Float = 1000.0 / 60.0;
  static var sessionStartMs:Float = 0.0;

  // Rolling FPS over a one-second window.
  static var fpsFrames:Int = 0;
  static var fpsClockMs:Float = 0.0;
  static var fps:Float = 0.0;

  // Session peaks / counters (reported in the footer).
  static var peakFrameMs:Float = 0.0;
  static var peakWorkMs:Float = 0.0;
  static var lagSpikes:Int = 0;
  static var extremeLagSpikes:Int = 0;
  static var traceLines:Int = 0;
  static var assetEvents:Int = 0;
  static var peakHeapBytes:Float = 0.0;
  static var peakRssBytes:Float = 0.0;

  static var lastRssBytes:Float = -1.0;
  static var rssFrames:Int = 0;

  // -- Public API -------------------------------------------------------------

  /**
   * Initializes the vlog. Call once, as early as possible at startup
   * (`Main` does this before `CrashHandler.init`, and on Android after the
   * storage directory became the working directory). Creates `vlog/`,
   * appends a session header to `vlog/log.txt` and hooks the global trace
   * so every engine/script trace is recorded.
   *
   * @param targetFps target framerate the log's lag thresholds are based on
   */
  public static function init(?targetFps:Float = 60.0):Void
  {
    if (initialized) return;
    initialized = true;
    sessionStartMs = nowMs();
    lastFlushMs = sessionStartMs;
    targetMs = (targetFps > 0.0) ? 1000.0 / targetFps : 1000.0 / 60.0;

    #if sys
    try
    {
      if (!FileSystem.exists(DIR)) FileSystem.createDirectory(DIR);
      rotateIfNeeded();
      fileReady = true;
    }
    catch (e:Dynamic)
      Sys.println('vlog: could not create ' + DIR + '/ (' + Std.string(e) + ') — vlog writes disabled for this session');
    #end

    // Session header.
    log('BOOT', '=== PHOENIX ENGINE VLOG — SESSION START ===');
    log('BOOT', 'engine: Phoenix v' + engineVersion() + ' (JSE v' + jseVersion() + ', Psych v' + psychVersion() + ')');
    #if debug
    final buildKind:String = 'debug';
    #else
    final buildKind:String = 'release';
    #end
    log('BOOT', 'target: ' + platformLabel() + ' (' + buildKind + ' build)'
      + ' | framerate budget: ' + round(targetMs, 3) + ' ms (' + Std.int(1000.0 / targetMs) + ' fps)');
    #if sys
    log('BOOT', 'cwd: ' + Sys.getCwd());
    final args = Sys.args();
    if (args.length > 0) log('BOOT', 'args: ' + args.join(' '));
    #end
    // Hardware, one line each — same source as the crash report.
    try
    {
      for (line in backend.Native.buildSystemInfo().split('\n'))
        log('BOOT', 'system: ' + StringTools.trim(line));
    }
    catch (e:Dynamic)
      log('BOOT', 'system: unavailable (' + Std.string(e) + ')');

    // Capture every trace() in the engine and in Lua/Python/HScript.
    haxe.Log.traceHook = onTrace;

    // Session footer on exit.
    #if !flash
    try
    {
      if (Application.current != null && Application.current.onExit != null)
      {
        _exitHooked = true;
        Application.current.onExit.add(function(_:Int) shutdown());
      }
    }
    catch (_:Dynamic) {}
    #end

    flush(true);
  }

  /** True once init() ran and (on file targets) writes are possible. */
  public static function isActive():Bool
  {
    #if sys
    return initialized && fileReady && !flushFailed;
    #else
    return initialized;
    #end
  }

  /**
   * Appends one tagged line to the vlog. Safe to call from anywhere: lines
   * are buffered and flushed at most every 250 ms, and on web/flash they
   * accumulate in the capped in-memory buffer.
   */
  public static function log(tag:String, message:String):Void
  {
    if (!initialized) return;

    buffer.add(formatLine(tag, message));
    // The buffer is bounded on every target: file targets flush it every
    // 250 ms, while web/flash (and a session without a writable vlog/)
    // drop the oldest half once it grows too large.
    if (buffer.length > MAX_WEB_CHARS) truncateBuffer();

    #if sys
    // flush() is a no-op unless fileReady && !flushFailed.
    flush();
    #end
  }

  /**
   * Called once per frame by the game loop (`FlxGame.onEnterFrame`). Records
   * the per-frame line, updates the rolling FPS and detects lag spikes.
   *
   * @param elapsedMs wall time since the previous frame (the vsync interval)
   * @param workMs    time spent in update + draw this frame
   * @param drawCalls draw calls issued this frame
   * @param updates   state updates executed this frame (fixed timestep > 1)
   * @param lostFocus true while the window lost focus and the game pauses
   */
  public static function onFrame(elapsedMs:Float, workMs:Float, drawCalls:Int, updates:Int, lostFocus:Bool):Void
  {
    if (!initialized) return;
    frameIndex++;

    fpsFrames++;
    fpsClockMs += elapsedMs;
    if (fpsClockMs >= 1000.0)
    {
      fps = fpsFrames * 1000.0 / fpsClockMs;
      fpsFrames = 0;
      fpsClockMs = 0.0;
    }

    if (elapsedMs > peakFrameMs) peakFrameMs = elapsedMs;
    if (workMs > peakWorkMs) peakWorkMs = workMs;

    final heap:Float = heapUsedBytes();
    if (heap > peakHeapBytes) peakHeapBytes = heap;
    if (++rssFrames >= RSS_EVERY_N_FRAMES)
    {
      rssFrames = 0;
      sampleRss();
    }

    log('FRAME', 'fps=' + round(fps, 1)
      + ' frame=' + round(elapsedMs, 3) + 'ms'
      + ' work=' + round(workMs, 3) + 'ms'
      + ' upd=' + updates
      + ' draws=' + drawCalls
      + ' heap=' + formatBytes(heap)
      + ' rss=' + formatBytes(lastRssBytes)
      + (lostFocus ? ' focus=lost' : '')
      + ' state=' + currentStateName());

    // Lag spike detection (a paused window is not a lag).
    if (!lostFocus && elapsedMs > 0.0)
    {
      final threshold = Math.max(targetMs * 2.0, LAG_SPIKE_MIN_MS);
      if (elapsedMs > threshold)
      {
        lagSpikes++;
        final extreme = elapsedMs > LAG_EXTREME_MS;
        if (extreme) extremeLagSpikes++;
        log(extreme ? 'EXTREME LAG' : 'LAG SPIKE', 'frame=' + round(elapsedMs, 3) + 'ms (budget ' + round(targetMs, 3) + 'ms, ' + round(elapsedMs / targetMs, 2) + 'x)'
          + ' work=' + round(workMs, 3) + 'ms'
          + ' outside=' + round(Math.max(elapsedMs - workMs, 0.0), 3) + 'ms (vsync wait / system stall)'
          + ' heap=' + formatBytes(heap)
          + ' rss=' + formatBytes(lastRssBytes)
          + ' state=' + currentStateName());
      }
    }
  }

  /** Logs a state switch (called from `FlxGame.switchState`). */
  public static function stateChanged(?from:String, to:String):Void
  {
    if (!initialized) return;
    if (from == null || from.length == 0)
      log('STATE', 'entered ' + to);
    else
      log('STATE', from + ' -> ' + to);
  }

  /**
   * Records a RAM asset-cache event: an image/sound/note skin entering the
   * cache, or a load that failed. `detail` is appended verbatim.
   */
  public static function assetCached(kind:String, key:String, detail:String = ''):Void
  {
    if (!initialized) return;
    assetEvents++;
    log('ASSET ' + kind.toUpperCase(), key + (detail.length > 0 ? ' | ' + detail : ''));
  }

  /** Records a memory-management event (clears, explicit GC, low memory…). */
  public static function memoryEvent(message:String):Void
  {
    if (!initialized) return;
    log('MEMORY', message);
  }

  /**
   * Records a script trace unconditionally. The in-game debug overlay is
   * gated by `luaDebugMode` / `pythonDebugMode`, but the vlog captures
   * everything — even when the overlay is off.
   */
  public static function scriptTrace(language:String, message:String):Void
  {
    if (!initialized) return;
    traceLines++;
    log('TRACE ' + language, message);
  }

  /**
   * Records an uncaught error (called from `CrashHandler`). Mirrors what
   * ends up in `crash/` so the live session log carries the same context,
   * then flushes immediately — the process may die right after.
   */
  public static function crash(message:String, stack:String = ''):Void
  {
    if (!initialized) return;
    log('CRASH', message);
    if (stack != null && stack.length > 0) log('CRASH STACK', stack);
    try
    {
      for (line in backend.Native.buildSystemInfo().split('\n'))
        log('CRASH SYSTEM', line);
    }
    catch (_:Dynamic) {}
    flush(true);
  }

  /** Managed-heap usage in bytes, -1 when the runtime does not expose it. */
  public static function heapUsedBytes():Float
  {
    try
    {
      return debug.Memory.gay();
    }
    catch (_:Dynamic)
      return -1.0;
  }

  /**
   * Web/flash builds cannot write to the user's filesystem; this triggers a
   * browser download of the in-memory log as `log.txt`. No-op on file
   * targets, where `vlog/log.txt` already exists on disk.
   */
  public static function download():Void
  {
    #if web
    try
    {
      OpenFlFile.download('log.txt', haxe.io.Bytes.ofString(exportText()), false);
    }
    catch (_:Dynamic) {}
    #end
  }

  /** The full log as text (reads the file on file targets, buffer on web). */
  public static function exportText():String
  {
    #if sys
    try
    {
      if (fileReady && FileSystem.exists(FILE))
        // …plus whatever is still in the in-memory buffer (≤ 250 ms).
        return File.getContent(FILE) + buffer.toString();
    }
    catch (_:Dynamic) {}
    #end
    return buffer.toString();
  }

  /**
   * Writes the session footer and force-flushes. Called from the
   * application exit hook; also safe to call manually.
   */
  public static function shutdown():Void
  {
    if (!initialized) return;
    try
    {
      final durationMs = nowMs() - sessionStartMs;
      log('BOOT', '=== PHOENIX ENGINE VLOG — SESSION END ===');
      log('BOOT', 'duration=' + round(durationMs / 1000.0, 2) + 's'
        + ' frames=' + frameIndex
        + ' fpsAvg=' + round(frameIndex * 1000.0 / Math.max(durationMs, 1.0), 2)
        + ' peakFrame=' + round(peakFrameMs, 3) + 'ms'
        + ' peakWork=' + round(peakWorkMs, 3) + 'ms'
        + ' lagSpikes=' + lagSpikes + ' (extreme=' + extremeLagSpikes + ')'
        + ' traceLines=' + traceLines
        + ' assetEvents=' + assetEvents
        + ' peakHeap=' + formatBytes(peakHeapBytes)
        + ' peakRss=' + formatBytes(peakRssBytes));
    }
    catch (_:Dynamic) {}
    flush(true);
  }

  /** Human-readable byte count for log lines ("214.3MB", "n/a"). */
  public static inline function formatBytes(bytes:Float):String
    return (bytes < 0.0) ? 'n/a' : MemoryUtil.formatMemory(bytes);

  // -- Internal ---------------------------------------------------------------

  static var _exitHooked:Bool = false;

  /**
   * `haxe.Log.traceHook`: records every `trace()` call from the engine,
   * Lua (`LuaUtils.luaTrace`), Python (`PythonScript.pyTrace`) and HScript
   * (the interpreter's built-in `trace`) — then mirrors it to the console,
   * because installing a hook replaces the default printer.
   */
  static function onTrace(value:Dynamic, ?posInfos:PosInfos, ?inlineParams:Array<Dynamic>):Void
  {
    try
    {
      traceLines++;
      var message:String = Std.string(value);
      if (inlineParams != null)
      {
        for (param in inlineParams)
          message += ' ' + Std.string(param);
      }
      if (posInfos != null && posInfos.fileName != null)
        message += '  [' + posInfos.fileName + ':' + posInfos.lineNumber + ']';
      log('TRACE ' + classifyTrace(posInfos), message);
    }
    catch (_:Dynamic) {}

    // Keep the console output intact.
    #if sys
    try
    {
      Sys.println(Std.string(value));
    }
    catch (_:Dynamic) {}
    #elseif js
    try
    {
      js.Browser.console.log(value);
    }
    catch (_:Dynamic) {}
    #end
  }

  /**
   * Tags the caller of a captured trace() so the log makes the source
   * obvious: `[Lua]`, `[Python]`, `[HScript]` or `[Engine]`.
   */
  static function classifyTrace(posInfos:PosInfos):String
  {
    if (posInfos == null || posInfos.fileName == null) return 'Engine';
    final file:String = posInfos.fileName;
    if (StringTools.endsWith(file, 'LuaUtils.hx')) return 'Lua';
    if (StringTools.endsWith(file, 'PythonScript.hx')) return 'Python';
    // hscript's built-in trace reports its expressions from "hscript"
    // (or the origin passed to parseString).
    if (file.contains('hscript')) return 'HScript';
    return 'Engine';
  }

  /** Drops the oldest half of the in-memory buffer (keeps it bounded). */
  static function truncateBuffer():Void
  {
    final keep:String = buffer.toString().substr(buffer.length - (MAX_WEB_CHARS / 2));
    buffer = new StringBuf();
    buffer.add('[' + timestamp() + '] [vlog] in-memory log exceeded ' + MemoryUtil.formatMemory(MAX_WEB_CHARS) + ' — oldest lines dropped\n');
    buffer.add(keep);
  }

  /** Flushes the buffer to disk when it is large or old enough. */
  public static function flush(force:Bool = false):Void
  {
    #if sys
    if (!initialized || !fileReady || flushFailed) return;
    if (buffer.length == 0) return;
    if (!force && buffer.length < FLUSH_CHARS && nowMs() - lastFlushMs < FLUSH_INTERVAL_MS) return;
    try
    {
      final f = File.write(FILE, true);
      f.writeBytes(haxe.io.Bytes.ofString(buffer.toString()));
      f.close();
      buffer = new StringBuf();
      lastFlushMs = nowMs();
      // Rotation stats are a directory scan; keep it to ~4x per second.
      if (++flushCount % 60 == 0) rotateIfNeeded();
    }
    catch (e:Dynamic)
    {
      // Storage full or removed: keep what is already on disk and stop
      // trying instead of growing an unbounded buffer.
      flushFailed = true;
      Sys.println('vlog: write to ' + FILE + ' failed (' + Std.string(e) + ') — vlog writes disabled for this session');
    }
    #end
  }

  /**
   * Rotates the log once it grows past MAX_LOG_BYTES:
   * `log.txt` -> `log.1.txt` -> `log.2.txt` (the oldest backup is dropped).
   */
  static function rotateIfNeeded():Void
  {
    if (!FileSystem.exists(FILE)) return;
    try
    {
      if (FileSystem.stat(FILE).size <= MAX_LOG_BYTES) return;
      final oldest = DIR + '/log.' + MAX_ROTATED + '.txt';
      if (FileSystem.exists(oldest)) FileSystem.deleteFile(oldest);
      for (i in MAX_ROTATED - 1...0)
      {
        final from = DIR + '/log.' + i + '.txt';
        if (FileSystem.exists(from))
          FileSystem.rename(from, DIR + '/log.' + (i + 1) + '.txt');
      }
      FileSystem.rename(FILE, DIR + '/log.1.txt');
      log('ROTATE', FILE + ' exceeded ' + MemoryUtil.formatMemory(MAX_LOG_BYTES) + ' and was rotated (log.1.txt … log.' + MAX_ROTATED + '.txt kept)');
    }
    catch (e:Dynamic)
      Sys.println('vlog: rotation failed: ' + Std.string(e));
  }

  /** Samples the process RSS (a syscall on desktop, throttled). */
  static function sampleRss():Void
  {
    try
    {
      final rss:Float = debug.mem.GetTotalMemory.getCurrentRSS();
      if (rss > 0.0)
      {
        lastRssBytes = rss;
        if (rss > peakRssBytes) peakRssBytes = rss;
      }
    }
    catch (_:Dynamic) {}
  }

  static function formatLine(tag:String, message:String):String
  {
    final clean:String = (message == null ? '' : message).replace('\r\n', '\n').replace('\r', '\n');
    final lines:Array<String> = clean.split('\n');
    final stamp:String = timestamp();
    final frame:String = 'f' + pad(frameIndex, 7);
    final out = new StringBuf();
    for (i in 0...lines.length)
    {
      if (i > 0) out.add('\n        ');
      out.add('[').add(stamp).add('] [').add(frame).add('] [').add(tag).add('] ').add(lines[i]);
    }
    out.add('\n');
    return out.toString();
  }

  static function timestamp():String
  {
    final d = Date.now();
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate()) + ' '
      + pad2(d.getHours()) + ':' + pad2(d.getMinutes()) + ':' + pad2(d.getSeconds())
      + '.' + pad3(d.getMilliseconds());
  }

  static function pad(value:Int, width:Int):String
  {
    var s:String = Std.string(value);
    while (s.length < width) s = '0' + s;
    return s;
  }

  static function pad2(value:Int):String
    return pad(value, 2);

  static function pad3(value:Int):String
    return pad(value, 3);

  static function round(value:Float, decimals:Int):String
  {
    final mult = Math.pow(10.0, decimals);
    return Std.string(Math.round(value * mult) / mult);
  }

  static function nowMs():Float
  {
    #if sys
    return Sys.time() * 1000.0;
    #else
    return Date.now().getTime();
    #end
  }

  static function currentStateName():String
  {
    try
    {
      if (FlxG.state != null)
      {
        final cls:Class<Dynamic> = Type.getClass(FlxG.state);
        if (cls != null) return Type.getClassName(cls);
      }
    }
    catch (_:Dynamic) {}
    return 'unknown';
  }

  static function engineVersion():String
  {
    // Same source of truth as MainMenuState: the application metadata that
    // project.hxp sets from its VERSION constant.
    #if !flash
    try
    {
      if (Application.current != null && Application.current.meta != null)
      {
        final v:String = Application.current.meta.get('version');
        if (v != null && v.length > 0) return v;
      }
    }
    catch (_:Dynamic) {}
    #end
    return '0.3.2';
  }

  // Kept in sync with MainMenuState's upstream compatibility markers.
  static function jseVersion():String
    return '1.51.0';

  static function psychVersion():String
    return '0.6.3';

  static function platformLabel():String
  {
    #if windows
    return 'windows (hxcpp)';
    #elseif mac
    return 'macos (hxcpp)';
    #elseif linux
    return 'linux (hxcpp)';
    #elseif android
    return 'android (hxcpp)';
    #elseif ios
    return 'ios (hxcpp)';
    #elseif hl
    return 'hashlink';
    #elseif neko
    return 'neko';
    #elseif web
    return 'html5';
    #elseif air
    return 'air';
    #elseif flash
    return 'flash';
    #else
    return 'unknown';
    #end
  }
}
