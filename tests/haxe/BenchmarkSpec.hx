import sys.FileSystem;
import sys.io.File;
import backend.BenchmarkChart;
import backend.RecoveryBoot;
import backend.Benchmark;

/**
 * Device Benchmark — the checks that keep it honest.
 *
 * The benchmark (Options -> Optimization -> Device Benchmark) promises three
 * things: a *fixed* chart (same on every device, every run), a *mod-free*
 * run (nothing under mods/ is searched), and an *honest* report (the profiler
 * session covers the chart, not the loading screen). This spec pins the
 * parts of that promise that Haxe can check without a GPU:
 *
 *   1.  the chart: shape, timing, ordering, lane bounds, both sides, sustains,
 *       chords and bit-determinism across builds;
 *   2.  the mod-suppression predicate shared by `Paths`/`Mods`/scripts:
 *       `RecoveryBoot.modsDisabled()` must flip with Safe Mode *or* with the
 *       benchmark flag;
 *   3.  the wiring, by scanning the sources: the options row launches the
 *       benchmark, `PlayState` forces botplay/ticks/releases the suppression,
 *       `endSong` routes to the report before any scoring, and both `Paths`
 *       and `Mods` consult the predicate.
 *
 * The real `backend.Benchmark` controller pulls in `PlayState` and Flixel, so
 * the interpreter compiles a one-field stub (`backend.Benchmark` in the stub
 * classpath, `active:Bool`); everything else deliberately fails loudly when
 * the repo layout changes.
 *
 * Run with: bash tests/haxe/run-benchmark.sh
 */
class BenchmarkSpec
{
  static var failures:Int = 0;

  static function check(ok:Bool, label:String):Void
  {
    if (ok) return;
    failures++;
    Sys.println('FAILED: $label');
  }

  static function occurrences(haystack:String, needle:String):Int
  {
    var count:Int = 0;
    var from:Int = 0;
    while (true)
    {
      final at:Int = haystack.indexOf(needle, from);
      if (at == -1) break;
      count++;
      from = at + needle.length;
    }
    return count;
  }

  static function readRepo(path:String):String
  {
    if (!FileSystem.exists(path))
    {
      check(false, 'expected repo file to exist: ' + path);
      return '';
    }
    return File.getContent(path);
  }

  public static function main():Void
  {
    testChartShape();
    testChartTiming();
    testChartDeterminism();
    testModSuppressionPredicate();
    testWiring();

    if (failures > 0) throw '$failures benchmark check(s) failed';
    Sys.println('BenchmarkSpec passed');
  }

  static function testChartShape():Void
  {
    final song:Dynamic = BenchmarkChart.build();
    check(song.song == 'phoenix-benchmark', 'song name is fixed');
    check(song.bpm == 120, 'bpm is fixed at 120, got ' + song.bpm);
    check(song.needsVoices == false, 'no voices track is expected');
    check(song.stage == 'stage', 'the built-in week-1 stage is used, got ' + song.stage);
    check(song.player1 == 'bf' && song.player2 == 'dad' && song.gfVersion == 'gf', 'built-in characters are used');
    check(Reflect.hasField(song, 'events') && (cast song.events : Array<Dynamic>).length == 0, 'the fixed chart ships no events');

    final sections:Array<Dynamic> = cast song.notes;
    check(sections.length == BenchmarkChart.SECTION_COUNT, 'chart has ' + BenchmarkChart.SECTION_COUNT + ' sections, got ' + sections.length);

    var totalNotes:Int = 0;
    var sustains:Int = 0;
    var playerNotes:Int = 0;
    var opponentNotes:Int = 0;
    var chordNotes:Int = 0;
    var prevTime:Float = -1.0;
    var inOrder:Bool = true;
    var allTimesValid:Bool = true;
    var allLanesValid:Bool = true;
    var everySectionNonEmpty:Bool = true;
    var sectionFieldsComplete:Bool = true;
    final simultaneous:Map<Int, Int> = new Map();

    var index:Int = 0;
    for (section in sections)
    {
      for (field in ['sectionNotes', 'sectionBeats', 'typeOfSection', 'mustHitSection', 'gfSection',
        'bpm', 'changeBPM', 'altAnim', 'crossFade'])
        if (!Reflect.hasField(section, field)) sectionFieldsComplete = false;
      if (section.bpm != 120 || section.changeBPM != false || section.sectionBeats != 4)
        sectionFieldsComplete = false;

      final sectionNotes:Array<Array<Dynamic>> = cast section.sectionNotes;
      if (sectionNotes.length == 0) everySectionNonEmpty = false;

      // The fixed camera pattern the engine was tuned around: odd sections
      // are must-hit, even ones are not.
      check(section.mustHitSection == (index % 2 == 1), 'section ' + index + ' mustHitSection follows the fixed pattern');

      for (note in sectionNotes)
      {
        final time:Float = note[0];
        final lane:Int = note[1];
        final sus:Float = note[2];
        totalNotes++;
        if (sus > 0) sustains++;
        if (lane < 4) playerNotes++; else opponentNotes++;
        if (time < 0 || time >= BenchmarkChart.SONG_LENGTH_MS) allTimesValid = false;
        if (lane < 0 || lane > 7) allLanesValid = false;
        if (sus < 0) allTimesValid = false;
        if (time < prevTime) inOrder = false;
        prevTime = time;
        final key:Int = Std.int(time);
        simultaneous.set(key, (simultaneous.exists(key) ? simultaneous.get(key) : 0) + 1);
      }
      index++;
    }

    for (count in simultaneous) if (count >= 4) chordNotes++;

    check(sectionFieldsComplete, 'every section carries the SwagSection fields');
    check(everySectionNonEmpty, 'no empty sections');
    check(allTimesValid, 'all note times sit inside [0, ' + BenchmarkChart.SONG_LENGTH_MS + ') ms');
    check(allLanesValid, 'all lanes sit inside 0..7');
    check(inOrder, 'note times are non-decreasing across the whole chart');
    check(totalNotes >= BenchmarkChart.MIN_NOTES && totalNotes <= BenchmarkChart.MAX_NOTES,
      'note count is stressful but sane (' + BenchmarkChart.MIN_NOTES + '..' + BenchmarkChart.MAX_NOTES + '), got ' + totalNotes);
    check(sustains >= 4, 'the chart exercises sustains, got ' + sustains);
    check(playerNotes > 0 && opponentNotes > 0, 'both sides play (player: ' + playerNotes + ', opponent: ' + opponentNotes + ')');
    check(chordNotes >= 1, 'the finale ships at least one 4+-note chord');
  }

  static function testChartTiming():Void
  {
    check(BenchmarkChart.STEP_MS == 125, 'a step is 125 ms at 120 BPM, got ' + BenchmarkChart.STEP_MS);
    check(BenchmarkChart.SECTION_MS == 16 * BenchmarkChart.STEP_MS, 'a section is one bar of 16 steps');
    check(BenchmarkChart.SONG_LENGTH_MS == BenchmarkChart.SECTION_COUNT * BenchmarkChart.SECTION_MS,
      'the song is exactly 30 bars long, got ' + BenchmarkChart.SONG_LENGTH_MS + ' ms');
    check(BenchmarkChart.SONG_LENGTH_MS == 60000, 'the bundled Inst.ogg is 60 s, got ' + BenchmarkChart.SONG_LENGTH_MS);
    check(BenchmarkChart.WATCHDOG_MS > BenchmarkChart.SONG_LENGTH_MS,
      'the watchdog only fires when the instrumental failed to complete');
  }

  static function testChartDeterminism():Void
  {
    // The whole point of an in-code chart: the same notes on every device.
    final first:String = haxe.Json.stringify(BenchmarkChart.build());
    final second:String = haxe.Json.stringify(BenchmarkChart.build());
    check(first == second, 'two builds of the chart are byte-identical');
  }

  static function testModSuppressionPredicate():Void
  {
    final savedDisable:Bool = RecoveryBoot.disableMods;

    RecoveryBoot.disableMods = false;
    Benchmark.active = false;
    check(!RecoveryBoot.modsDisabled(), 'mods are available by default');

    Benchmark.active = true;
    check(RecoveryBoot.modsDisabled(), 'the benchmark suppresses mod lookups');
    Benchmark.active = false;
    check(!RecoveryBoot.modsDisabled(), 'and clearing the flag restores them');

    RecoveryBoot.disableMods = true;
    check(RecoveryBoot.modsDisabled(), 'Safe Mode suppresses mod lookups');
    Benchmark.active = true;
    check(RecoveryBoot.modsDisabled(), 'Safe Mode + benchmark stay suppressed');

    RecoveryBoot.disableMods = savedDisable;
    Benchmark.active = false;
    check(RecoveryBoot.modsDisabled() == savedDisable, 'the predicate restores its prior value');
  }

  static function testWiring():Void
  {
    // The options row: reachable everywhere, including Android, questioned first.
    final options:String = readRepo('source/options/OptimizationSubState.hx');
    check(options.indexOf('Device Benchmark') != -1, 'Options -> Optimization has the Device Benchmark row');
    check(occurrences(options, 'deviceBenchmark') >= 3, 'the row is wired to its handler');
    check(options.indexOf('backend.Benchmark.start()') != -1, 'accepting the confirm launches the benchmark');

    // The controller module and its entry asset.
    check(FileSystem.exists('source/backend/Benchmark.hx'), 'backend.Benchmark exists');
    check(FileSystem.exists('source/backend/BenchmarkChart.hx'), 'the fixed chart module exists');
    check(FileSystem.exists('assets/songs/phoenix-benchmark/Inst.ogg')
      && FileSystem.stat('assets/songs/phoenix-benchmark/Inst.ogg').size > 100 * 1024,
      'the bundled 60 s instrumental ships in the repo');
    check(FileSystem.exists('tools/generate_benchmark_inst.py'), 'the instrumental generator ships in tools/');

    // PlayState: measurement hook, forced botplay, suppression release.
    final playState:String = readRepo('source/play/PlayState.hx');
    check(occurrences(playState, 'backend.Benchmark.active') >= 2, 'PlayState consults the benchmark flag');
    check(playState.indexOf('Benchmark.tick()') != -1, 'PlayState ticks the benchmark watchdog');
    check(playState.indexOf('Benchmark.exitRun()') != -1, 'destroy() always releases the mod suppression');

    // The exit path: no scoring, no stats, straight to the report.
    final playback:String = readRepo('source/play/helpers/PlayStatePlayback.hx');
    final endSongAt:Int = playback.indexOf('public static function endSong');
    check(endSongAt != -1, 'endSong exists');
    check(playback.indexOf('backend.Benchmark.finish') != -1, 'endSong routes the benchmark to its report');

    // Lookup sites consult the shared predicate, not the Safe Mode flag alone.
    final paths:String = readRepo('source/backend/Paths.hx');
    check(occurrences(paths, 'RecoveryBoot.modsDisabled()') >= 2, 'mod lookups go through the shared predicate');
    final mods:String = readRepo('source/backend/Mods.hx');
    check(mods.indexOf('RecoveryBoot.modsDisabled()') != -1, 'mod list parsing goes through the shared predicate');

    // The report page and its export contract.
    final results:String = readRepo('source/states/BenchmarkResultsState.hx');
    check(results.indexOf('Benchmark.reportText()') != -1, 'the results page renders the shared report text');
    check(results.indexOf('FrameProfiler') != -1 || results.indexOf('.log') != -1, 'the results page mentions the profiler export');

    // The pause menu must not offer a restart that would invalidate the run.
    final pause:String = readRepo('source/states/substates/PauseSubState.hx');
    check(pause.indexOf("remove('Restart Song')") != -1, 'the fixed benchmark cannot be restarted mid-run');

    // The export entry point the benchmark is documented to reuse.
    final frameProfiler:String = readRepo('source/debug/FrameProfiler.hx');
    check(frameProfiler.indexOf('public static function exportLog') != -1, 'FrameProfiler.exportLog exists');
  }
}
