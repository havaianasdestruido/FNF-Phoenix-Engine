package backend;

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
 * Device Benchmark — a fixed, mod-free test run (Options -> Optimization).
 *
 * What it is: the built-in `phoenix-benchmark` chart (see `backend.BenchmarkChart`)
 * played on the built-in `stage` stage with botplay on, no mods loaded and no
 * score saved. It measures the ~60 second chart and then reports average FPS,
 * 1% low, worst frame and the device it ran on, and it writes a full
 * `FrameProfiler` export to `debug/log/benchmark_<timestamp>.log`.
 *
 * What it is not: the live FPS/frametime counter (that is the F3 overlay /
 * Legacy FPS UI) and not a synthetic timer loop. The point is to exercise the
 * real gameplay pipeline — stage, characters, HUD, notes, splashes, camera —
 * so the numbers describe an actual device under an actual chart.
 *
 * Mod-free: `active` is checked by `Paths`, `Mods` and the script loader
 * alongside `RecoveryBoot.disableMods`. `PlayState` clears it in `destroy()`,
 * so *any* exit from the benchmark — finishing, pausing and leaving, a crash
 * in the state — restores normal mod lookups (the call also restores the
 * pre-run `Mods.currentModDirectory` and invalidates `Paths`' lookup cache,
 * which the fixed chart may have poisoned with misses for modded keys).
 * `active` is never persisted.
 *
 * The measurement itself starts when the instrumental starts (`Conductor.songPosition
 * >= 0`), not at state creation: the loading screen and the countdown are not
 * part of the result. `FrameProfiler.reset()` is called at that same moment, so
 * the report covers exactly the chart. Leaving before the chart ends discards
 * the run — nothing is saved and no report is shown.
 *
 * Botplay is forced for the run, the pause menu drops "Restart Song" and
 * "Change Difficulty" while it is active, and the end path returns before the
 * highscore/stat/achievement bookkeeping runs.
 */
@:access(play.PlayState)
class Benchmark
{
  /** True from `start()` until the benchmark's PlayState is destroyed. Suppresses mod asset/script lookups. */
  public static var active(default, null):Bool = false;

  /** Path of the `FrameProfiler` export written at the end of the last run, or `""` when it could not be written. */
  public static var exportPath(default, null):String = '';

  /** Frame statistics captured when the last run ended, or `null` before the first one completes. */
  public static var summary(default, null):Null<FrameProfileSummary> = null;

  /** Human readable timestamp of when the last run finished. */
  public static var completedAt(default, null):String = '';

  static var started:Bool = false;
  static var finishing:Bool = false;
  static var startStamp:Float = 0.0;
  /** `Mods.currentModDirectory` at the moment `start()` ran; restored by `exitRun()`. */
  static var savedModDirectory:String = null;

  /**
   * Builds the fixed benchmark song and registers `mods` as unavailable for it.
   * Call `LoadingState.loadAndSwitchState(PlayState.new)` afterwards, or just use `start()`.
   */
  public static function chart():SwagSong
  {
    final song:SwagSong = cast BenchmarkChart.build();
    // The stage resolution below reads SONG.stage; loadDirectory also sets the
    // shared directory override PlayState consumes.
    StageData.loadDirectory(song);
    Song.loadedSongName = BenchmarkChart.SONG_NAME;
    return song;
  }

  /**
   * Starts the benchmark: builds the chart, arms botplay + mod suppression and
   * switches into the loading screen. The caller is expected to have saved
   * preferences already (Options -> Optimization does).
   */
  public static function start():Void
  {
    // Mod suppression starts before ANYTHING resolves an asset path — the fixed
    // stage must not be shadowable by a mod, so it cannot start after chart().
    active = true;
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

    PlayState.SONG = chart();
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
    exportPath = FrameProfiler.exportLog('benchmark_' + DateTools.format(Date.now(), '%Y-%m-%d_%H-%M-%S'));

    active = false; // the PlayState reports destroyed-mod-suppression on its way out anyway
    FlxG.switchState(() -> new states.BenchmarkResultsState());
  }

  /**
   * Drops the suppression without producing a report. `PlayState.destroy()`
   * calls this so every exit path restores normal mod lookups.
   */
  public static function exitRun():Void
  {
    active = false;
    started = false;
    finishing = false;
    // Hand the mod environment back exactly as the run found it: the pause
    // menu's "Exit to Freeplay" calls Mods.loadTopMod() while the suppression
    // is still active (which zeroes currentModDirectory), and the fixed chart
    // poisoned Paths' lookup cache with misses for modded keys.
    if (savedModDirectory != null)
    {
      backend.Mods.currentModDirectory = savedModDirectory;
      savedModDirectory = null;
      backend.Paths.invalidateAssetLookupCache();
    }
  }

  /** The plain-text report behind the results screen (and its clipboard copy). */
  public static function reportText():String
  {
    final out:Array<String> = [];
    final sum = summary;
    final info = Native.getSystemInfo();

    out.push('Phoenix Engine - Device Benchmark');
    out.push('Date: ' + (completedAt != '' ? completedAt : Date.now().toString()));
    out.push('Run: fixed chart "phoenix-benchmark" on the built-in stage, botplay, mods disabled');
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

  /** Short label used by the results screen title line. */
  public static function oneLineSummary():String
  {
    if (summary == null || summary.totalFrames <= 0)
      return 'No frames recorded.';
    return 'Avg ' + fmt(summary.avgFps, 1) + ' FPS  |  1% low ' + fmt(summary.onePercentLowFps, 1)
      + ' FPS  |  worst ' + fmt(summary.maxFrameTimeMs, 2) + ' ms';
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
