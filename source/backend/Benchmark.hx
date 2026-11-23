package backend;

import backend.BenchmarkKind;
import backend.BenchmarkKindTools;
import backend.BenchmarkSynthetic;
import DateTools;
import debug.FrameProfiler;
import debug.FrameProfiler.FrameProfileSummary;
import data.Song;
import data.StageData;
import states.MainMenuState;
import states.LoadingState;
import play.PlayState;
import flixel.FlxG;

/**
 * Device Benchmark suite — fixed, mod-free test runs (Options -> Optimization).
 *
 * What it is: a set of deterministic, mod-free charts that exercise different
 * subsystems so a report can say *where* a device bottlenecks instead of just
 * \"it stuttered\":
 *
 *  - `GAMEPLAY` — the original balanced 60 s chart (`phoenix-benchmark`);
 *  - `VISUAL` — visual stress: chords + sustains + splash-heavy finale that
 *    hammers the renderer and draw-call path;
 *  - `LOGIC` — logic stress: jacks, trills and 16th bursts that hammer
 *    spawning, sorting and the update loop;
 *  - `SYNTHETIC` — pure-Haxe micro-benchmarks (JSON parse, sort, path ops,
 *    BPM math, alloc/GC, trig, hash) with no stage, audio or `PlayState`;
 *  - `SUITE` — runs `SYNTHETIC` immediately and reports it, then invites the
 *    player to run the gameplay charts to complete a full profile.
 *
 * All gameplay kinds share the same 60 s `Inst.ogg` and the same `FrameProfiler`
 * measurement contract: `FrameProfiler.reset()` when `Conductor.songPosition
 * >= 0`, never at state creation, so the loading screen and countdown are not
 * part of the result. `SYNTHETIC` never touches `FrameProfiler`; it records
 * its own `BenchmarkSynthetic.SyntheticResult`.
 *
 * Mod-free: `active` is checked by `Paths`, `Mods` and the script loader
 * alongside `RecoveryBoot.disableMods`. `PlayState` clears it in `destroy()`,
 * so *any* exit from a gameplay benchmark — finishing, pausing and leaving, a
 * crash in the state — restores normal mod lookups (the call also restores
 * the pre-run `Mods.currentModDirectory` and invalidates `Paths`' lookup cache,
 * which the fixed charts may have poisoned with misses for modded keys).
 * `active` is never persisted.
 *
 * Botplay is forced for every gameplay run, the pause menu drops \"Restart
 * Song\" and \"Change Difficulty\" while it is active, and the end path returns
 * before the highscore/stat/achievement bookkeeping runs.
 */
@:access(play.PlayState)
class Benchmark
{
  /** True from `start*()` until the benchmark's PlayState is destroyed (or the synthetic run lands on results). Suppresses mod asset/script lookups. */
  public static var active(default, null):Bool = false;

  /** Which kind is currently running, or `null` before the first run. */
  public static var kind(default, null):Null<BenchmarkKind> = null;

  /** For `SUITE` / `SYNTHETIC` runs: the micro-benchmark result, or `null` before the first synthetic run. */
  public static var syntheticResult(default, null):Null<BenchmarkSynthetic.SyntheticResult> = null;

  /** Path of the `FrameProfiler` export written at the end of the last gameplay run, or `\"\"` when it could not be written. */
  public static var exportPath(default, null):String = '';

  /** Frame statistics captured when the last gameplay run ended, or `null` before the first one completes. */
  public static var summary(default, null):Null<FrameProfileSummary> = null;

  /** Human readable timestamp of when the last run finished. */
  public static var completedAt(default, null):String = '';

  static var started:Bool = false;
  static var finishing:Bool = false;
  static var startStamp:Float = 0.0;
  /** `Mods.currentModDirectory` at the moment `start*()` ran; restored by `exitRun()`. */
  static var savedModDirectory:String = null;

  /**
   * Builds the fixed benchmark song for `kind` and registers `mods` as
   * unavailable for it. Call `LoadingState.loadAndSwitchState(PlayState.new)`
   * afterwards, or just use `startKind(kind)`.
   *
   * `SYNTHETIC`/`SUITE` have no `PlayState` chart; `null` is returned and
   * `startKind` branches before calling this.
   */
  public static function chart():SwagSong
  {
    // Legacy callers (and the spec) call `chart()` with no kind — they mean GAMEPLAY.
    return chartKind(GAMEPLAY);
  }

  public static function chartKind(kind:BenchmarkKind):SwagSong
  {
    final chart:Dynamic = BenchmarkChart.buildKind(kind);
    if (chart == null) return null;
    StageData.loadDirectory(chart);
    Song.loadedSongName = chart.song;
    return cast chart;
  }

  /**
   * Starts the benchmark for `kind`. The caller is expected to have saved
   * preferences already (Options -> Optimization does). `null` means GAMEPLAY
   * for callers that pre-date the suite.
   */
  public static function start():Void
    startKind(GAMEPLAY);

  public static function startKind(?kind:BenchmarkKind):Void
  {
    final resolved:BenchmarkKind = kind == null ? GAMEPLAY : kind;
    switch (resolved)
    {
      case SYNTHETIC:
        startSynthetic();
        return;
      case SUITE:
        startSuite();
        return;
      case GAMEPLAY | VISUAL | LOGIC:
        // fall through to gameplay path
    }

    // Gameplay path: mod suppression starts before ANYTHING resolves an asset path.
    active = true;
    Benchmark.kind = resolved;
    started = false;
    finishing = false;
    exportPath = '';
    summary = null;
    savedModDirectory = backend.Mods.currentModDirectory;

    // Gear up for a clean, single-purpose run.
    CoolUtil.difficulties = (CoolUtil.difficulties == null || CoolUtil.difficulties.length == 0)
      ? CoolUtil.defaultDifficulties.copy()
      : CoolUtil.difficulties;
    CoolUtil.currentDifficulty = CoolUtil.difficulties[1].toUpperCase(); // 'NORMAL'

    PlayState.SONG = chartKind(resolved);
    PlayState.isStoryMode = false;
    PlayState.wasOriginallyFreeplay = false;
    PlayState.storyDifficulty = 1;
    PlayState.chartingMode = false;
    PlayState.seenCutscene = false;
    PlayState.startOnTime = 0;
    PlayState.prevCamFollow = null;
    PlayState.prevCamFollowPos = null;
    PlayState.campaignResults = null;
    PlayState.campaignScore = 0;
    PlayState.campaignMisses = 0;
    PlayState.changedDifficulty = false;

    // Menu fade is handled by the loading screen like any other song.
    if (FlxG.sound.music != null)
      FlxG.sound.music.volume = 0;
    FlxG.mouse.visible = false;
    LoadingState.loadAndSwitchState(PlayState.new);
  }

  /** Convenience: start the visual stress chart. */
  public static inline function startVisual():Void
    startKind(VISUAL);

  /** Convenience: start the logic stress chart. */
  public static inline function startLogic():Void
    startKind(LOGIC);

  /**
   * Runs the synthetic micro-benchmarks right now (no song, no stage) and
   * lands on the results screen. Mod suppression is armed briefly so
   * `RecoveryBoot.modsDisabled()` is true while the result is captured, then
   * cleared by the results screen's `destroy()` / `Benchmark.exitRun()` path.
   */
  public static function startSynthetic():Void
  {
    active = true;
    kind = SYNTHETIC;
    started = false;
    finishing = false;
    exportPath = '';
    summary = null;
    // Synthetic never dirties mod lookups, but keep the same restore pattern
    // so callers that branch on `savedModDirectory != null` stay honest.
    savedModDirectory = backend.Mods.currentModDirectory;

    syntheticResult = BenchmarkSynthetic.run();
    completedAt = syntheticResult.timestamp;
    // No FrameProfiler session for synthetic; keep `summary` null and let
    // `reportText()` render the synthetic block instead.
    exportPath = '';

    // Briefly keep `active` so the results screen can style itself as a
    // benchmark page, then `exitRun()` on that screen's teardown restores the
    // mod directory exactly as the gameplay path does.
    FlxG.switchState(() -> new states.BenchmarkResultsState());
  }

  /**
   * The \"Full Suite\" entry: run synthetic now, then present the combined
   * report that also explains how to complete the suite with visual/logic runs.
   */
  public static function startSuite():Void
  {
    active = true;
    kind = SUITE;
    started = false;
    finishing = false;
    exportPath = '';
    summary = null;
    savedModDirectory = backend.Mods.currentModDirectory;
    syntheticResult = BenchmarkSynthetic.run();
    completedAt = syntheticResult.timestamp;
    FlxG.switchState(() -> new states.BenchmarkResultsState());
  }

  /**
   * Per-frame hook (called from `PlayState.update`). Starts the measurement
   * when the instrumental starts, and force-ends the run if the instrumental
   * never completes — stripped builds ship no audio at all, and a benchmark
   * that cannot end is worse than a silent one.
   */
  public static function tick():Void
  {
    if (!active || finishing)
      return;
    // Synthetic/suite never reach a PlayState.
    if (kind == SYNTHETIC || kind == SUITE)
      return;

    if (!started)
    {
      // Conductor.songPosition only reaches zero once the countdown ends.
      if (backend.Conductor.songPosition >= 0)
      {
        started = true;
        // Cover exactly the chart, not the loading screen or the countdown.
        FrameProfiler.reset();
        startStamp = haxe.Timer.stamp();
      }
      return;
    }

    if ((haxe.Timer.stamp() - startStamp) * 1000.0 >= BenchmarkChart.WATCHDOG_MS)
    {
      finishing = true;
      final state:PlayState = PlayState.instance;
      if (state != null)
      {
        trace('[Benchmark] Instrumental never completed; force-ending the run.');
        state.finishSong(true);
      }
    }
  }

  /**
   * Ends the run. Called from `PlayStatePlayback.endSong` *before* any of the
   * normal bookkeeping (highscores, stats, achievements, results screen):
   * a benchmark is not a play session and must not look like one.
   */
  public static function finish(state:PlayState):Void
  {
    if (finishing)
      return;
    finishing = true;

    // The same silence the regular end-of-song path asks for. The watchdog
    // path can reach here while the instrumental is still playing, and the
    // music outlives the state switch — stop it explicitly.
    if (FlxG.sound.music != null) FlxG.sound.music.stop();
    if (state.vocals != null) state.vocals.stop();
    if (state.opponentVocals != null) state.opponentVocals.stop();
    if (state.mobileControls != null) state.mobileControls.visible = false;
    if (state.virtualPad != null) state.virtualPad.visible = false;
    state.timeBarBG.visible = false;
    state.timeBar.visible = false;
    state.timeTxt.visible = false;
    state.canPause = false;
    state.endingSong = true;
    state.inCutscene = false;
    state.updateTime = false;
    state.startedCountdown = false;
    backend.Metronome.stop();

    summary = FrameProfiler.getSummary();
    completedAt = Date.now().toString();
    final tag:String = kindTag(kind);
    exportPath = FrameProfiler.exportLog('benchmark_' + tag + '_' + DateTools.format(Date.now(), '%Y-%m-%d_%H-%M-%S'));

    active = false; // the PlayState reports destroyed-mod-suppression on its way out anyway
    FlxG.switchState(() -> new states.BenchmarkResultsState());
  }

  /**
   * Drops the suppression without producing a report. `PlayState.destroy()`
   * calls this so every exit path restores normal mod lookups. The results
   * screen also calls it if the player leaves without finishing a gameplay run.
   */
  public static function exitRun():Void
  {
    active = false;
    started = false;
    finishing = false;
    // Hand the mod environment back exactly as the run found it: the pause
    // menu's \"Exit to Freeplay\" calls Mods.loadTopMod() while the suppression
    // is still active (which zeroes currentModDirectory), and the fixed chart
    // poisoned Paths' lookup cache with misses for modded keys.
    if (savedModDirectory != null)
    {
      backend.Mods.currentModDirectory = savedModDirectory;
      savedModDirectory = null;
      backend.Paths.invalidateAssetLookupCache();
    }
  }

  // ---- Reporting -----------------------------------------------------------

  /** The plain-text report behind the results screen (and its clipboard copy). */
  public static function reportText():String
  {
    // Synthetic/suite have a dedicated formatter.
    if (kind == SYNTHETIC || kind == SUITE)
      return reportSuiteText();

    final out:Array<String> = [];
    final sum = summary;
    final info = Native.getSystemInfo();
    final k:BenchmarkKind = kind == null ? GAMEPLAY : kind;
    final tag:String = BenchmarkKindTools.displayName(k);
    final id:String = BenchmarkKindTools.id(k);

    out.push('Phoenix Engine - Device Benchmark (' + tag + ')');
    out.push('Date: ' + (completedAt != '' ? completedAt : Date.now().toString()));
    out.push('Run: fixed chart \"' + id + '\" on the built-in stage, botplay, mods disabled');
    out.push('Kind: ' + BenchmarkKindTools.shortLabel(k) + ' — ' + BenchmarkKindTools.description(k));
    out.push('');

    out.push('[FRAME PERFORMANCE]');
    if (sum == null || sum.totalFrames <= 0)
    {
      out.push('No frames recorded.');
    }
    else
    {
      final seconds:Float = sum.sessionDurationMs / 1000.0;
      out.push('Target FPS        : ' + fmt(sum.targetFps, 0));
      out.push('Total frames      : ' + sum.totalFrames + ' (' + fmt(seconds, 1) + ' s measured)');
      out.push('Average FPS       : ' + fmt(sum.avgFps, 1) + ' (' + fmt(sum.avgFrameTimeMs, 2) + ' ms/frame)');
      out.push('1% low            : ' + fmt(sum.onePercentLowFps, 1) + ' FPS (p99 ' + fmt(sum.p99FrameTimeMs, 2) + ' ms)');
      out.push('0.1% low          : ' + fmt(sum.pointOnePercentLowFps, 1) + ' FPS (p99.9 ' + fmt(sum.p999FrameTimeMs, 2) + ' ms)');
      out.push('Worst frame       : ' + fmt(sum.maxFrameTimeMs, 2) + ' ms (' + fmt(1000.0 / Math.max(0.001, sum.maxFrameTimeMs), 1) + ' FPS)');
      out.push('P50 / P95 frametime: ' + fmt(sum.p50FrameTimeMs, 2) + ' / ' + fmt(sum.p95FrameTimeMs, 2) + ' ms');
      out.push('1% low (harmonic) : ' + fmt(sum.slowest1PctAvgFps, 1) + ' FPS');
      out.push('Dropped frames    : ' + sum.droppedFrames);
      out.push('Spikes >16/25/33/50 ms: ' + sum.spikeCount16Ms + ' / ' + sum.spikeCount25Ms + ' / ' + sum.spikeCount33Ms + ' / ' + sum.spikeCount50Ms);
      out.push('Avg update/render : ' + fmt(sum.avgUpdateTimeMs, 2) + ' / ' + fmt(sum.avgRenderTimeMs, 2) + ' ms');
      out.push('Max update/render : ' + fmt(sum.maxUpdateTimeMs, 2) + ' / ' + fmt(sum.maxRenderTimeMs, 2) + ' ms');
      out.push('Avg draw calls    : ' + fmt(sum.avgDrawCalls, 1) + '  (max ' + sum.maxDrawCalls + ')');
    }
    out.push('');

    // Kind-specific guidance.
    out.push('[KIND ANALYSIS]');
    switch (k)
    {
      case VISUAL:
        out.push('Visual stress leans on render time, draw calls and splash/GPU load.');
        out.push('A low visual score with a good synthetic score = GPU/render bound.');
        if (sum != null && sum.totalFrames > 0)
        {
          final renderHeavy:Bool = sum.avgRenderTimeMs > sum.avgUpdateTimeMs * 1.4;
          out.push(renderHeavy
            ? 'This run was render-heavy (render > 1.4x update). Reduce shaders/GPU cache to gain headroom.'
            : 'Render and update were balanced. If this still stutters, try the Logic benchmark.');
        }
      case LOGIC:
        out.push('Logic stress leans on spawn/sort/update and input timing.');
        out.push('A low logic score with a good synthetic score = per-frame CPU bound.');
        if (sum != null && sum.totalFrames > 0)
        {
          final logicHeavy:Bool = sum.avgUpdateTimeMs > sum.avgRenderTimeMs * 1.4;
          out.push(logicHeavy
            ? 'This run was update-heavy (update > 1.4x render). Try a lower scroll speed or fewer active scripts.'
            : 'Update and render were balanced.');
        }
      case GAMEPLAY:
        out.push('Balanced chart — a baseline for visual vs logic deltas.');
        out.push('Run Visual and Logic to see which side bottlenecks first.');
      default:
    }
    // Cross-report synthetic if we have one from the same boot.
    if (syntheticResult != null)
    {
      out.push('');
      out.push('[SYNTHETIC (from this boot)]');
      out.push('Score ' + fmt(syntheticResult.score, 1) + ' | ' + fmt(syntheticResult.totalMs, 1) + ' ms total');
      for (s in syntheticResult.samples)
        out.push('  ' + pad(s.name, 14) + fmt(s.avgMs, 3) + ' ms avg  (' + fmt(s.score, 1) + ')');
    }
    out.push('');

    out.push('[DEVICE]');
    out.push('OS                : ' + trimPair(info.osName, info.osVersion));
    out.push('GPU               : ' + info.gpuModel);
    out.push('GPU vendor        : ' + info.gpuVendor);
    out.push('GPU driver        : ' + info.gpuDriver);
    out.push('Graphics API      : ' + info.graphicsApi);
    out.push('Audio             : ' + info.audioApi);
    out.push('CPU               : ' + info.cpuModel);
    out.push('CPU cores         : ' + debug.system.SystemInfo.logicalCPUCount());
    out.push('Total RAM         : ' + byteText(debug.system.SystemInfo.totalPhysicalMemory()));
    out.push('Engine            : Phoenix v' + PhoenixVersion.current
      + ((MainMenuState.gitCommit != null && MainMenuState.gitCommit.length > 0) ? ' (commit ' + MainMenuState.gitCommit + ')' : ''));
    out.push('Window / target   : ' + FlxG.width + 'x' + FlxG.height + ' @ ' + fmt(ClientPrefs.framerate, 0) + ' FPS');
    out.push('');

    out.push('[EXPORT]');
    out.push(exportPath != ''
      ? 'Full FrameProfiler log: ' + exportPath
      : 'Full FrameProfiler log: unavailable on this target (or the write failed)');
    out.push('The export contains the per-frame timeline and may include paths;');
    out.push('redact it before posting it publicly.');
    return out.join('\n');
  }

  static function reportSuiteText():String
  {
    final k:BenchmarkKind = kind == null ? SYNTHETIC : kind;
    // SYNTHETIC: just the synthetic report.
    if (k == SYNTHETIC && syntheticResult != null)
      return BenchmarkSynthetic.formatReport(syntheticResult);

    // SUITE: synthetic plus guidance + last gameplay frame block if we have one.
    final out:Array<String> = [];
    if (syntheticResult != null)
    {
      out.push(BenchmarkSynthetic.formatReport(syntheticResult));
    }
    else
    {
      out.push('Phoenix Engine - Benchmark Suite');
      out.push('Date: ' + (completedAt != '' ? completedAt : Date.now().toString()));
      out.push('');
      out.push('[SYNTHETIC]');
      out.push('No synthetic result yet — re-open the suite to re-run it.');
    }
    out.push('');
    out.push('[SUITE — NEXT STEPS]');
    out.push('Synthetic (CPU) is done. To complete a full profile:');
    out.push('  1. Run VISUAL  — render-heavy chart (~60 s)');
    out.push('  2. Run LOGIC   — update-heavy chart (~60 s)');
    out.push('  3. Return here — the suite report keeps the last synthetic score for comparison.');
    // If we have a gameplay summary from earlier in this boot, show it inline.
    final sum = summary;
    if (sum != null && sum.totalFrames > 0)
    {
      out.push('');
      out.push('[LAST GAMEPLAY RUN]');
      if (kind != null) out.push('Kind: ' + BenchmarkKindTools.displayName(kind));
      out.push('Avg ' + fmt(sum.avgFps, 1) + ' FPS | 1% low ' + fmt(sum.onePercentLowFps, 1) + ' | worst ' + fmt(sum.maxFrameTimeMs, 2) + ' ms');
      out.push('Update/render: ' + fmt(sum.avgUpdateTimeMs, 2) + ' / ' + fmt(sum.avgRenderTimeMs, 2) + ' ms | draws avg ' + fmt(sum.avgDrawCalls, 1));
      if (exportPath != '') out.push('Log: ' + exportPath);
    }
    else
    {
      out.push('');
      out.push('No gameplay run yet this boot. Run Gameplay, Visual or Logic to fill the suite.');
    }
    return out.join('\n');
  }

  /** Short label used by the results screen title line. */
  public static function oneLineSummary():String
  {
    if (kind == SYNTHETIC || kind == SUITE)
    {
      if (syntheticResult == null) return 'No synthetic data.';
      return BenchmarkSynthetic.oneLineSummary(syntheticResult);
    }
    if (summary == null || summary.totalFrames <= 0)
      return 'No frames recorded.';
    final label:String = kind == null ? '' : BenchmarkKindTools.shortLabel(kind) + ' | ';
    return label + 'Avg ' + fmt(summary.avgFps, 1) + ' FPS  |  1% low ' + fmt(summary.onePercentLowFps, 1)
      + ' FPS  |  worst ' + fmt(summary.maxFrameTimeMs, 2) + ' ms';
  }

  // ---- Helpers -------------------------------------------------------------

  static function kindTag(k:Null<BenchmarkKind>):String
  {
    if (k == null) return 'gameplay';
    return switch (k)
    {
      case GAMEPLAY: 'gameplay';
      case VISUAL: 'visual';
      case LOGIC: 'logic';
      case SYNTHETIC: 'synthetic';
      case SUITE: 'suite';
    };
  }

  static function pad(s:String, width:Int):String
  {
    if (s.length >= width) return s.substr(0, width);
    var out:String = s;
    while (out.length < width) out += ' ';
    return out;
  }

  static function fmt(value:Float, decimals:Int):String
  {
    if (Math.isNaN(value) || Math.isFinite(value) == false)
      return 'N/A';
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
    if (bytes <= 0 || Math.isNaN(bytes))
      return 'unavailable';
    if (bytes >= 1024.0 * 1024.0 * 1024.0)
      return fmt(bytes / (1024.0 * 1024.0 * 1024.0), 1) + ' GB';
    return fmt(bytes / (1024.0 * 1024.0), 0) + ' MB';
  }
}
