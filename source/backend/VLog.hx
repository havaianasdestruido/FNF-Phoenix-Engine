package backend;

/*
 * Phoenix Engine VLog — the "everything" log.
 *
 * The vlog is **off by default**: it only starts when the player enables
 * `Options → Misc → "Enable VLog"` (saved as `ClientPrefs.vlogEnabled`).
 * When enabled it records a running, aggressively verbose session log at
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
 *    calls, managed heap, process RSS, current state, and a per-area RAM
 *    breakdown (engine assets / mod assets / engine code / mod code /
 *    Haxe-Flixel runtime reserved) from `backend.MemoryLedger`;
 *  - a detailed RAM line every ~second and on every state change: per-area
 *    CPU + GPU bytes, asset/script counts, exact Lua vs. estimated interpreter
 *    memory, the GC reserved pool, and the top mods by RAM;
 *  - lag spikes: any frame over max(2x budget, 25 ms) gets a dedicated
 *    LAG SPIKE line; over 100 ms it is called out as EXTREME;
 *  - every `trace()` in the engine and in the scripting runtimes — Lua
 *    (`luaTrace`), Python (`pyTrace`) and HScript (the interpreter's built-in
 *    `trace`) — captured through a rebound `haxe.Log.trace` and tagged with
 *    the originating language;
 *  - RAM asset-cache events: images cached (CPU bitmap vs GPU texture),
 *    sounds decoded, note skins, `clearStoredMemory` / `clearUnusedMemory`
 *    results and every explicit GC/compact with heap before/after;
 *  - state changes and uncaught errors (crashes), mirrored from
 *    `CrashHandler` so the live log carries the same context as `crash/`.
 *
 * The writer is fail-safe: any filesystem problem disables vlog writes for
 * the session (with a console notice) instead of taking the game down, and
 * lines are buffered in memory and flushed at most every 250 ms so a crash
 * never loses more than a quarter second of log. Paths and local usernames are
 * redacted before disk writes and exports; the 10 MiB live file rotates by
 * size/age and keeps at most two backups.
 *
 * Even with the vlog off, the last `TAIL_MAX_CHARS` of the session log are
 * kept in memory (traces, boot lines, state changes, crashes) so
 * `Options -> Misc -> "Copy Diagnostics"` can attach a log tail without
 * writing anything to disk and without asking the player to enable the vlog
 * first. Nothing is ever uploaded: the copy goes to the system clipboard.
 */

import flixel.FlxG;
import haxe.PosInfos;
#if sys
import Sys;
import sys.FileSystem;
import sys.io.File;
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
  /** Expire the live log and its rotated backups after this many days. */
  static inline final MAX_LOG_AGE_DAYS:Int = 30;
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
  /** Emit the detailed per-area RAM breakdown line at most once per N frames. */
  static inline final RAM_DETAIL_EVERY_N_FRAMES:Int = 60;

  /**
   * Size of the always-on in-memory tail (64 KiB). It is recorded whether or
   * not a vlog session is open, so "Copy Diagnostics" can quote the end of
   * the session log on a default install; it is a plain `StringBuf` with no
   * allocation per frame beyond the lines this class already handles.
   */
  static inline final TAIL_MAX_CHARS:Int = 65536;

  // -- Session state ---------------------------------------------------------

  static var initialized:Bool = false;
  static var fileReady:Bool = false;
  static var flushFailed:Bool = false;

  static var buffer:StringBuf = new StringBuf();
  static var lastFlushMs:Float = 0.0;
  static var flushCount:Int = 0;
  static var rotationInProgress:Bool = false;

  /**
   * End of the session log, kept even while the vlog is off (see
   * `recentText()`). Bounded by `TAIL_MAX_CHARS`; `tailChars` counts the
   * characters appended since the last trim so the length check stays O(1).
   */
  static var tailBuffer:StringBuf = new StringBuf();
  static var tailChars:Int = 0;

  static var frameIndex:Int = 0;
  static var targetMs:Float = 1000.0 / 60.0;
  static var sessionStartMs:Float = 0.0;
  /**
   * Work time of the previous frame callback. `elapsedMs` runs from the
   * previous callback's start to this one's, so when the previous callback
   * overran (a long state create(), a GC storm) its cost lands in this
   * frame's elapsed time — subtracting it is the only way to report the
   * real vsync/pump wait instead of blaming the innocent frame.
   */
  static var prevWorkMs:Float = 0.0;

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

  // Per-area RAM peaks (reported in the footer), from the memory ledger.
  static var peakEngineAssets:Float = 0.0;
  static var peakModAssets:Float = 0.0;
  static var peakEngineCode:Float = 0.0;
  static var peakModCode:Float = 0.0;
  static var peakRuntime:Float = 0.0;
  static var ramDetailFrames:Int = 0;

  static var lastRssBytes:Float = -1.0;
  static var rssFrames:Int = 0;

  // -- Opt-in switch ---------------------------------------------------------

  /**
   * Whether the vlog records anything at all. Off by default; the player
   * flips it from `Options → Misc → "Enable VLog"` (`ClientPrefs.vlogEnabled`)
   * and `Main` restores the saved value on boot.
   */
  public static var enabled:Bool = false;

  /** Framerate `init()` was called with, reused by a late `setEnabled(true)`. */
  static var bootTargetFps:Float = 60.0;
  /** When `init()` ran, so a late start can report how late it is. */
  static var bootMs:Float = 0.0;
  /** `haxe.Log.trace` as it was before the vlog rebound it (restored on stop). */
  static var previousTrace:Dynamic = null;

  // -- Public API -------------------------------------------------------------

  /**
   * Prepares the vlog. Call once, as early as possible at startup
   * (`Main` does this before `CrashHandler.init`, and on Android after the
   * storage directory became the working directory).
   *
   * The vlog is dormant unless it was already enabled: while it is off,
   * nothing is created on disk and `trace()` is left untouched, so the whole
   * feature costs nothing. `setEnabled(true)` starts it at any point later.
   *
   * @param targetFps    target framerate the log's lag thresholds are based on
   * @param startEnabled start logging right away (default: stay off until the
   *                     player turns it on from Options → Misc)
   */
  public static function init(?targetFps:Float = 60.0, ?startEnabled:Null<Bool> = null):Void
  {
    bootMs = nowMs();
    bootTargetFps = (targetFps > 0.0) ? targetFps : 60.0;
    if (startEnabled != null) enabled = startEnabled;
    if (initialized) return;
    seedTail();
    if (!enabled) return;
    startSession();
  }

  /**
   * Turns the vlog on or off at runtime (`Options → Misc → "Enable VLog"`).
   * Enabling starts a session immediately; disabling writes the session
   * footer, flushes to disk and restores the default `trace()` behaviour.
   *
   * @param on        new state
   * @param targetFps optional framerate budget to use from now on
   */
  public static function setEnabled(on:Bool, ?targetFps:Float = null):Void
  {
    if (targetFps != null && targetFps > 0.0) bootTargetFps = targetFps;
    enabled = on;
    if (on)
    {
      if (!initialized) startSession();
    }
    else if (initialized)
      endSession('VLOG DISABLED FROM OPTIONS', true);
  }

  /**
   * Opens a session: creates `vlog/`, appends the session header to
   * `vlog/log.txt`, hooks `trace()` and registers the exit footer.
   */
  static function startSession():Void
  {
    if (initialized) return;
    initialized = true;
    fileReady = false;
    flushFailed = false;
    sessionStartMs = nowMs();
    lastFlushMs = sessionStartMs;
    targetMs = 1000.0 / bootTargetFps;
    resetSessionStats();

    #if sys
    try
    {
      if (!FileSystem.exists(DIR)) FileSystem.createDirectory(DIR);
      // Evaluate age before sanitizing (rewriting) would update file mtimes.
      pruneExpiredRotations();
      rotateIfNeeded();
      pruneExpiredRotations();
      sanitizeStoredLogs();
      fileReady = true;
    }
    catch (e:Dynamic)
      Sys.println('vlog: could not create ' + DIR + '/ (' + Std.string(e) + ') — vlog writes disabled for this session');
    #end

    // Session header.
    log('BOOT', '=== PHOENIX ENGINE VLOG — SESSION START ===');
    if (bootMs > 0.0 && nowMs() - bootMs > 1000.0)
      log('BOOT', 'late start: enabled ' + round((nowMs() - bootMs) / 1000.0, 2)
        + 's after boot from Options -> Misc');
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
    // Haxe 4.3 rebinds trace through haxe.Log.trace (no traceHook yet).
    // Remember the original printer so disabling the vlog restores it.
    previousTrace = haxe.Log.trace;
    haxe.Log.trace = onTrace;

    // Session footer on exit.
    #if !flash
    try
    {
      if (!_exitHooked && Application.current != null && Application.current.onExit != null)
      {
        _exitHooked = true;
        Application.current.onExit.add(function(_:Int) shutdown());
      }
    }
    catch (_:Dynamic) {}
    #end

    flush(true);
  }

  /** True while a session is open and (on file targets) writes are possible. */
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
   *
   * The always-on tail is recorded even when no session is open, which is
   * what lets "Copy Diagnostics" quote the end of the session on a default
   * install without writing a file; `buffer` and the flush are still
   * session-only, so nothing reaches `vlog/log.txt` unless the player enabled
   * it.
   */
  public static function log(tag:String, message:String):Void
  {
    final line:String = formatLine(tag, message);
    // The tail is recorded from the same formatted line as the file, so a
    // later diagnostics copy reads exactly like vlog/log.txt.
    appendTail(line);

    if (!initialized) return;

    buffer.add(line);
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
   * @param elapsedMs wall time since the previous frame callback started
   *                  (start-to-start: includes the previous callback's runtime)
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
    else if (workMs > targetMs)
    {
      // RSS is a syscall, so the frame cadence above normally throttles it —
      // but a callback that overran (state create() decoding assets, a GC
      // storm) blocks all frames while the heap moves hundreds of MB, and
      // the next FRAME line would print the pre-freeze RSS: rss below the
      // current heap, and MemoryLedger's runtime = RSS - heap clamped to 0B
      // (seen in the transition frames of vlog/log.txt). Refresh after any
      // over-budget callback so the line stays self-consistent.
      sampleRss();
    }

    // Per-area RAM attribution (engine/mod assets, engine/mod code, runtime).
    // One snapshot per frame feeds the FRAME line, the peaks and the periodic
    // detailed breakdown, so the ledger is only walked once.
    final ram:MemoryLedger.MemorySnapshot = MemoryLedger.snapshot(heap, lastRssBytes);
    final ramCompact:String = MemoryLedger.formatCompact(ram);
    if (ram.engineAssets.ram > peakEngineAssets) peakEngineAssets = ram.engineAssets.ram;
    if (ram.modAssets.ram > peakModAssets) peakModAssets = ram.modAssets.ram;
    if (ram.engineCode.ram > peakEngineCode) peakEngineCode = ram.engineCode.ram;
    if (ram.modCode.ram > peakModCode) peakModCode = ram.modCode.ram;
    if (ram.runtime.ram > peakRuntime) peakRuntime = ram.runtime.ram;

    log('FRAME', 'fps=' + round(fps, 1)
      + ' frame=' + round(elapsedMs, 3) + 'ms'
      + ' work=' + round(workMs, 3) + 'ms'
      + ' upd=' + updates
      + ' draws=' + drawCalls
      + ' heap=' + formatBytes(heap)
      + ' rss=' + formatBytes(lastRssBytes)
      + ' ' + ramCompact
      + (lostFocus ? ' focus=lost' : '')
      + ' state=' + currentStateName());

    // Detailed per-area breakdown ~once a second (counts, GPU, Lua vs. interp,
    // GC reserved pool, top mods). State changes log one immediately too.
    if (++ramDetailFrames >= RAM_DETAIL_EVERY_N_FRAMES)
    {
      ramDetailFrames = 0;
      log('RAM', MemoryLedger.formatDetailed(ram));
    }

    // Lag spike detection (a paused window is not a lag).
    //
    // `elapsedMs` is start-to-start, so a long PREVIOUS callback (a state
    // create() full of asset decodes, a GC storm) lands in this frame's
    // elapsed time: the frame that actually did the work reported a tiny
    // elapsed and was never flagged, and the next frame got blamed for all
    // of it with a bogus "vsync wait" outside figure (e.g. frame=17ms
    // work=1812ms going unflagged, then frame=2206ms outside=2206ms).
    // Split the stall correctly instead: `workMs` is this callback's own
    // cost, `gapMs` is the real wait after the previous callback ended —
    // flag whichever side overran the budget.
    final gapMs = Math.max(elapsedMs - prevWorkMs, 0.0);
    prevWorkMs = workMs;
    if (!lostFocus)
    {
      final threshold = Math.max(targetMs * 2.0, LAG_SPIKE_MIN_MS);
      final spikeMs = Math.max(workMs, gapMs);
      if (spikeMs > threshold)
      {
        lagSpikes++;
        final extreme = spikeMs > LAG_EXTREME_MS;
        if (extreme) extremeLagSpikes++;
        log(extreme ? 'EXTREME LAG' : 'LAG SPIKE', 'frame=' + round(elapsedMs, 3) + 'ms (budget ' + round(targetMs, 3) + 'ms, ' + round(spikeMs / targetMs, 2) + 'x)'
          + ' work=' + round(workMs, 3) + 'ms'
          + ' outside=' + round(gapMs, 3) + 'ms (vsync wait / system stall)'
          + ' heap=' + formatBytes(heap)
          + ' rss=' + formatBytes(lastRssBytes)
          + ' ' + ramCompact
          + ' state=' + currentStateName());
      }
    }
  }

  /** Logs a state switch (called from `FlxGame.switchState`). */
  public static function stateChanged(?from:String, to:String):Void
  {
    if (from == null || from.length == 0)
      log('STATE', 'entered ' + to);
    else
      log('STATE', from + ' -> ' + to);
    // A per-area RAM snapshot at every transition makes it easy to see what a
    // state left behind / is about to load. Reset the periodic counter so the
    // ~1 s detailed line does not immediately duplicate this one.
    logMemoryDetail();
    ramDetailFrames = 0;
  }

  /**
   * Emits a detailed per-area RAM breakdown line on demand (state changes,
   * memory-management events). Safe to call any time after `init`.
   */
  public static function logMemoryDetail():Void
  {
    log('RAM', MemoryLedger.formatDetailed(MemoryLedger.snapshot(heapUsedBytes(), lastRssBytes)));
  }

  /**
   * Records a RAM asset-cache event: an image/sound/note skin entering the
   * cache, or a load that failed. `detail` is appended verbatim.
   */
  public static function assetCached(kind:String, key:String, detail:String = ''):Void
  {
    assetEvents++;
    log('ASSET ' + kind.toUpperCase(), key + (detail.length > 0 ? ' | ' + detail : ''));
  }

  /** Records a memory-management event (clears, explicit GC, low memory…). */
  public static function memoryEvent(message:String):Void
  {
    log('MEMORY', message);
  }

  /**
   * Records a script trace unconditionally. The in-game debug overlay is
   * gated by `luaDebugMode` / `pythonDebugMode`, but the vlog captures
   * everything — even when the overlay is off.
   */
  public static function scriptTrace(language:String, message:String):Void
  {
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
    #if js
    try
    {
      final blob = new js.html.Blob([exportText()], {type: 'text/plain'});
      final url = js.html.URL.createObjectURL(blob);
      final anchor = js.Browser.document.createAnchorElement();
      anchor.href = url;
      anchor.download = 'log.txt';
      anchor.click();
      js.html.URL.revokeObjectURL(url);
    }
    catch (_:Dynamic) {}
    #end
  }

  /**
   * The end of the session log as text, newest last — available whether or
   * not a vlog session is open.
   *
   * When the vlog is on, this is `exportText()` (the whole file plus the
   * unflushed buffer) and the caller slices the end itself. When it is off,
   * the always-on in-memory tail is returned instead, so "Copy Diagnostics"
   * still has a few hundred lines of context on a default install.
   */
  public static function recentText():String
  {
    if (initialized)
    {
      #if sys
      // Only the end of the file is needed, and the file can be up to
      // MAX_LOG_BYTES: reading the last TAIL_MAX_CHARS keeps a copy on a weak
      // device from allocating the whole log just to throw it away.
      if (fileReady)
      {
        final tail:String = readFileTail(FILE, TAIL_MAX_CHARS);
        if (tail != null) return tail + buffer.toString();
      }
      #end
      return exportText();
    }
    return tailBuffer.toString();
  }

  /**
   * Reads at most the last `maxChars` of `path`, starting on a line boundary.
   *
   * The first line is dropped when the read started mid-file: half a stack
   * frame reads like corruption in a pasted report. Returns null when the
   * file cannot be read, so the caller can fall back.
   */
  static function readFileTail(path:String, maxChars:Int):String
  {
    #if sys
    try
    {
      if (!FileSystem.exists(path)) return null;
      final size:Int = FileSystem.stat(path).size;
      if (size <= 0) return '';
      final start:Int = (size > maxChars) ? size - maxChars : 0;
      final input:sys.io.FileInput = File.read(path, false);
      var text:String = '';
      try
      {
        if (start > 0) input.seek(start, sys.io.FileSeek.SeekBegin);
        text = input.readAll().toString();
      }
      catch (_:Dynamic) {}
      input.close();
      if (start == 0) return text;
      final cut:Int = text.indexOf('\n');
      return (cut == -1) ? '' : text.substr(cut + 1);
    }
    catch (_:Dynamic) {}
    #end
    return null;
  }

  /** The full log as text (reads the file on file targets, buffer on web). */
  public static function exportText():String
  {
    var content:String = buffer.toString();
    #if sys
    try
    {
      if (fileReady && FileSystem.exists(FILE))
        // …plus whatever is still in the in-memory buffer (≤ 250 ms).
        content = File.getContent(FILE) + content;
    }
    catch (_:Dynamic) {}
    #end
    // Also sanitize legacy content and the not-yet-flushed in-memory tail.
    return LogUtils.redact(content);
  }

  /**
   * Writes the session footer and force-flushes. Called from the
   * application exit hook; also safe to call manually.
   */
  public static function shutdown():Void
    endSession('SESSION END');

  /**
   * Closes the current session: footer with the session totals, a forced
   * flush, and (when turned off at runtime) the original `trace()` restored
   * so a disabled vlog behaves exactly like a build without it.
   */
  static function endSession(reason:String, restoreTrace:Bool = false):Void
  {
    if (!initialized) return;
    try
    {
      final durationMs = nowMs() - sessionStartMs;
      log('BOOT', '=== PHOENIX ENGINE VLOG — ' + reason + ' ===');
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
      log('BOOT', 'peakRam{engAssets=' + formatBytes(peakEngineAssets)
        + ' modAssets=' + formatBytes(peakModAssets)
        + ' engCode=' + formatBytes(peakEngineCode)
        + ' modCode=' + formatBytes(peakModCode)
        + ' runtime=' + formatBytes(peakRuntime) + '}');
    }
    catch (_:Dynamic) {}
    flush(true);
    initialized = false;
    fileReady = false;
    if (restoreTrace && previousTrace != null)
    {
      haxe.Log.trace = previousTrace;
      previousTrace = null;
    }
  }

  /** Zeroes the per-session counters so a later session starts fresh. */
  static function resetSessionStats():Void
  {
    frameIndex = 0;
    prevWorkMs = 0.0;
    flushCount = 0;
    fpsFrames = 0;
    fpsClockMs = 0.0;
    fps = 0.0;
    peakFrameMs = 0.0;
    peakWorkMs = 0.0;
    lagSpikes = 0;
    extremeLagSpikes = 0;
    traceLines = 0;
    assetEvents = 0;
    peakHeapBytes = 0.0;
    peakRssBytes = 0.0;
    lastRssBytes = -1.0;
    rssFrames = 0;
  }

  /** Human-readable byte count for log lines ("214.3MB", "n/a"). */
  public static inline function formatBytes(bytes:Float):String
    return (bytes < 0.0) ? 'n/a' : MemoryUtil.formatMemory(bytes);

  // -- Internal ---------------------------------------------------------------

  static var _exitHooked:Bool = false;

  /**
   * Rebound `haxe.Log.trace` (Haxe 4.3 has no `traceHook`): records every
   * `trace()` call from the engine, Lua (`LuaUtils.luaTrace`), Python
   * (`PythonScript.pyTrace`) and HScript (the interpreter's built-in
   * `trace`) — then mirrors it to the console, because rebinding `trace`
   * replaces the default printer.
   *
   * The signature must match `haxe.Log.trace` exactly — Haxe 4.3 rejects a
   * function with extra parameters. Multi-argument `trace(v, a, b)` passes
   * the extra values through `PosInfos.customParams`.
   */
  static function onTrace(value:Dynamic, ?posInfos:PosInfos):Void
  {
    try
    {
      traceLines++;
      var message:String = Std.string(value);
      if (posInfos != null)
      {
        if (posInfos.customParams != null)
        {
          for (param in posInfos.customParams)
            message += ' ' + Std.string(param);
        }
        if (posInfos.fileName != null)
          message += '  [' + posInfos.fileName + ':' + posInfos.lineNumber + ']';
      }
      log('TRACE ' + classifyTrace(posInfos), message);
    }
    catch (_:Dynamic) {}

    // Keep the console output intact: format it exactly like the default
    // haxe.Log.trace would have.
    #if sys
    try
    {
      Sys.println(haxe.Log.formatOutput(value, posInfos));
    }
    catch (_:Dynamic) {}
    #elseif js
    try
    {
      js.Browser.console.log(haxe.Log.formatOutput(value, posInfos));
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

  /**
   * Writes the one-line boot header into the always-on tail.
   *
   * With the vlog off nothing else marks the start of the run, so a
   * diagnostics copy taken before any other event would show only its own
   * `[BOOT]` line. The header costs one line of memory and is the same
   * information `vlog/log.txt` starts with; it is never written to disk.
   */
  static function seedTail():Void
  {
    #if debug
    final buildKind:String = 'debug';
    #else
    final buildKind:String = 'release';
    #end
    log('BOOT', 'engine: Phoenix v' + engineVersion() + ' | target: ' + platformLabel()
      + ' (' + buildKind + ' build) | vlog off (Options -> Misc)');
  }

  /**
   * Appends to the always-on tail, trimming it once it outgrew
   * `TAIL_MAX_CHARS`. Trimming keeps the newest half (plus any line the cut
   * split, which `DiagnosticsReport.tail` drops again on the way out).
   */
  static function appendTail(line:String):Void
  {
    tailBuffer.add(line);
    tailChars += line.length;
    if (tailChars <= TAIL_MAX_CHARS) return;

    final full:String = tailBuffer.toString();
    final keep:Int = Std.int(TAIL_MAX_CHARS / 2);
    // Not Math.max(): it returns Float, and substr() wants an Int (same
    // reason truncateBuffer() derives its half-point explicitly).
    var start:Int = (full.length > keep) ? full.length - keep : 0;
    // Snap forward to the next line boundary, so `recentText()` always starts
    // on a whole line instead of half a stack frame. `DiagnosticsReport.tail`
    // drops a cut continuation line as well; this is the cheaper first cut.
    final boundary:Int = full.indexOf('\n', start);
    if (boundary != -1) start = boundary + 1;
    tailBuffer = new StringBuf();
    tailBuffer.add(full.substr(start));
    tailChars = tailBuffer.length;
  }

  /** True while a vlog session is open, i.e. the file is being written. */
  public static function isRecording():Bool
    return initialized;

  /** Where the live log is written, relative to the working directory. */
  public static function filePath():String
    return FILE;

  /** Drops the oldest half of the in-memory buffer (keeps it bounded). */
  static function truncateBuffer():Void
  {
    // Int / Int is a Float in Haxe, so derive the half-point explicitly as an
    // Int before calling substr(pos:Int).
    final half:Int = Std.int(MAX_WEB_CHARS / 2);
    final keep:String = buffer.toString().substr(buffer.length - half);
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
      // File.write() truncates; File.append() keeps the previous content and
      // starts writing at the end of the file (text mode: binary = false).
      final f = File.append(FILE, false);
      // Redact at the disk boundary so even the Android VLogs document root
      // never exposes raw usernames or machine-specific absolute paths.
      f.write(haxe.io.Bytes.ofString(LogUtils.redact(buffer.toString())));
      f.close();
      buffer = new StringBuf();
      lastFlushMs = nowMs();
      // Check size after every write; age cleanup is a much less frequent scan.
      flushCount++;
      rotateIfNeeded();
      if (flushCount % 60 == 0) pruneExpiredRotations();
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
   * Rotates the live log after the size or age limit:
   * `log.txt` -> `log.1.txt` -> `log.2.txt` (oldest backup is dropped).
   */
  static function rotateIfNeeded():Void
  {
    #if sys
    if (rotationInProgress || !FileSystem.exists(FILE)) return;
    try
    {
      final stat = FileSystem.stat(FILE);
      final ageMs:Float = Date.now().getTime() - stat.mtime.getTime();
      final maxAgeMs:Float = MAX_LOG_AGE_DAYS * 24.0 * 60.0 * 60.0 * 1000.0;
      if (stat.size <= MAX_LOG_BYTES && ageMs < maxAgeMs) return;

      rotationInProgress = true;
      final oldest = DIR + '/log.' + MAX_ROTATED + '.txt';
      if (FileSystem.exists(oldest)) FileSystem.deleteFile(oldest);
      for (i in MAX_ROTATED - 1...0)
      {
        final from = DIR + '/log.' + i + '.txt';
        if (FileSystem.exists(from))
          FileSystem.rename(from, DIR + '/log.' + (i + 1) + '.txt');
      }
      FileSystem.rename(FILE, DIR + '/log.1.txt');
      log('ROTATE', FILE + ' reached its size/age limit and was rotated (log.1.txt … log.' + MAX_ROTATED + '.txt kept)');
    }
    catch (e:Dynamic)
      Sys.println('vlog: rotation failed: ' + Std.string(e));
    rotationInProgress = false;
    #end
  }

  /** Redacts this and previous VLog files before they can be copied out. */
  static function sanitizeStoredLogs():Void
  {
    #if sys
    for (path in [FILE, DIR + '/log.1.txt', DIR + '/log.2.txt'])
    {
      if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
        continue;
      try
      {
        // An unexpectedly large file from an older unbounded build is safer
        // to discard than to load wholesale or expose unsanitized.
        if (FileSystem.stat(path).size > MAX_LOG_BYTES)
        {
          FileSystem.deleteFile(path);
          continue;
        }
        final original:String = File.getContent(path);
        final safe:String = LogUtils.limitText(LogUtils.redact(original), MAX_LOG_BYTES);
        if (safe != original)
          File.saveContent(path, safe);
      }
      catch (_:Dynamic)
      {
        try
        {
          if (FileSystem.exists(path)) FileSystem.deleteFile(path);
        }
        catch (_:Dynamic) {}
      }
    }
    #end
  }

  /** Deletes age-expired rotated session files. */
  static function pruneExpiredRotations():Void
  {
    #if sys
    final cutoff:Float = Date.now().getTime() - MAX_LOG_AGE_DAYS * 24.0 * 60.0 * 60.0 * 1000.0;
    for (i in 1...(MAX_ROTATED + 1))
    {
      final path = DIR + '/log.' + i + '.txt';
      if (!FileSystem.exists(path) || FileSystem.isDirectory(path))
        continue;
      try
      {
        if (FileSystem.stat(path).mtime.getTime() < cutoff)
          FileSystem.deleteFile(path);
      }
      catch (_:Dynamic) {}
    }
    #end
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
      out.add('[');
      out.add(stamp);
      out.add('] [');
      out.add(frame);
      out.add('] [');
      out.add(tag);
      out.add('] ');
      out.add(lines[i]);
    }
    out.add('\n');
    return out.toString();
  }

  static function timestamp():String
  {
    final d = Date.now();
    // haxe.Date has no getMilliseconds(); derive the sub-second part from
    // getTime() (ms since the epoch).
    final ms:Int = Std.int(d.getTime() % 1000);
    return d.getFullYear() + '-' + pad2(d.getMonth() + 1) + '-' + pad2(d.getDate()) + ' '
      + pad2(d.getHours()) + ':' + pad2(d.getMinutes()) + ':' + pad2(d.getSeconds())
      + '.' + pad3(ms);
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
    return PhoenixVersion.current;
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
