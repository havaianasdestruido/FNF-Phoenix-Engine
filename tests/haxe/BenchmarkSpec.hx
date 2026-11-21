import sys.FileSystem;
import sys.io.File;
import backend.BenchmarkChart;
import backend.BenchmarkKind;
import backend.BenchmarkKindTools;
import backend.BenchmarkSynthetic;
import backend.RecoveryBoot;
import backend.Benchmark;

/**
 * Device Benchmark — the checks that keep it honest (now the expanded suite).
 *
 * The benchmark promises: fixed charts (same on every device, every run),
 * mod-free runs (nothing under mods/ is searched), and an honest report.
 * The suite expands the original single chart to three gameplay charts plus
 * a synthetic CPU suite:
 *
 *   1.  GAMEPLAY — balanced 60 s (the original);
 *   2.  VISUAL   — render-heavy 60 s (chords/sustains/splashes);
 *   3.  LOGIC    — logic-heavy 60 s (jacks/trills/16ths);
 *   4.  SYNTHETIC — 9 CPU micro-benchmarks, no PlayState.
 *
 * Plus the kind model, the wiring, and the mod-suppression predicate.
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
    testChartShapeVisual();
    testChartShapeLogic();
    testChartTiming();
    testChartTimingStress();
    testChartDeterminism();
    testChartDeterminismStress();
    testKindModel();
    testSynthetic();
    testSuiteChartDispatch();
    testModSuppressionPredicate();
    testWiring();
    testWiringSuite();

    if (failures > 0) throw '$failures benchmark check(s) failed';
    Sys.println('BenchmarkSpec passed');
  }

  // ---- Original gameplay chart ------------------------------------------------

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

  static function assertChartShape(song:Dynamic, songName:String, minNotes:Int, maxNotes:Int, label:String):Void
  {
    check(song.song == songName, label + ' song name is ' + songName + ', got ' + song.song);
    check(song.bpm == 120, label + ' bpm is 120, got ' + song.bpm);
    check(Reflect.hasField(song, 'events') && (cast song.events : Array<Dynamic>).length == 0, label + ' ships no events');
    final sections:Array<Dynamic> = cast song.notes;
    check(sections.length == BenchmarkChart.SECTION_COUNT, label + ' has ' + BenchmarkChart.SECTION_COUNT + ' sections, got ' + sections.length);
    var total:Int = 0;
    var sustains:Int = 0;
    var player:Int = 0;
    var opp:Int = 0;
    var prev:Float = -1.0;
    var inOrder:Bool = true;
    var lanesOk:Bool = true;
    var timesOk:Bool = true;
    var empty:Bool = false;
    for (s in sections)
    {
      final sectionNotes:Array<Array<Dynamic>> = cast s.sectionNotes;
      if (sectionNotes.length == 0) empty = true;
      for (note in sectionNotes)
      {
        final t:Float = note[0];
        final lane:Int = note[1];
        final sus:Float = note[2];
        total++;
        if (sus > 0) sustains++;
        if (lane < 4) player++; else opp++;
        if (lane < 0 || lane > 7) lanesOk = false;
        if (t < 0 || t >= BenchmarkChart.SONG_LENGTH_MS) timesOk = false;
        if (t < prev) inOrder = false;
        prev = t;
      }
    }
    check(!empty, label + ' has no empty sections');
    check(timesOk, label + ' times inside [0, SONG_LENGTH_MS)');
    check(lanesOk, label + ' lanes inside 0..7');
    check(inOrder, label + ' times are non-decreasing');
    check(total >= minNotes && total <= maxNotes, label + ' note count in ' + minNotes + '..' + maxNotes + ', got ' + total);
    check(sustains >= 3, label + ' exercises sustains, got ' + sustains);
    check(player > 0 && opp > 0, label + ' both sides play (p:' + player + ' o:' + opp + ')');
  }

  static function testChartShapeVisual():Void
  {
    final song:Dynamic = BenchmarkChart.buildVisual();
    assertChartShape(song, BenchmarkChart.VISUAL_SONG_NAME, BenchmarkChart.VISUAL_MIN_NOTES, BenchmarkChart.VISUAL_MAX_NOTES, 'visual');
    // Visual should be heavier than gameplay.
    final gameplay:Dynamic = BenchmarkChart.build();
    final gNotes:Int = countNotes(gameplay);
    final vNotes:Int = countNotes(song);
    check(vNotes > gNotes, 'visual is denser than gameplay (' + vNotes + ' > ' + gNotes + ')');
  }

  static function testChartShapeLogic():Void
  {
    final song:Dynamic = BenchmarkChart.buildLogic();
    assertChartShape(song, BenchmarkChart.LOGIC_SONG_NAME, BenchmarkChart.LOGIC_MIN_NOTES, BenchmarkChart.LOGIC_MAX_NOTES, 'logic');
    final gameplay:Dynamic = BenchmarkChart.build();
    final gNotes:Int = countNotes(gameplay);
    final lNotes:Int = countNotes(song);
    check(lNotes > gNotes, 'logic is denser than gameplay (' + lNotes + ' > ' + gNotes + ')');
  }

  static function countNotes(song:Dynamic):Int
  {
    var n:Int = 0;
    final sections:Array<Dynamic> = cast song.notes;
    for (s in sections) n += (cast s.sectionNotes : Array<Dynamic>).length;
    return n;
  }

  // ---- Timing ----------------------------------------------------------------

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

  static function testChartTimingStress():Void
  {
    // Visual/logic share the same wall clock so they reuse the same Inst.ogg.
    // This pins the invariant the watchdog and audio depend on.
    check(BenchmarkChart.VISUAL_SONG_NAME != BenchmarkChart.SONG_NAME, 'visual has its own song name');
    check(BenchmarkChart.LOGIC_SONG_NAME != BenchmarkChart.SONG_NAME, 'logic has its own song name');
    check(BenchmarkChart.VISUAL_MIN_NOTES > BenchmarkChart.MIN_NOTES, 'visual lower bound is above gameplay lower bound');
    check(BenchmarkChart.LOGIC_MIN_NOTES > BenchmarkChart.MIN_NOTES, 'logic lower bound is above gameplay lower bound');
  }

  static function testChartDeterminism():Void
  {
    final first:String = haxe.Json.stringify(BenchmarkChart.build());
    final second:String = haxe.Json.stringify(BenchmarkChart.build());
    check(first == second, 'two builds of the chart are byte-identical');
  }

  static function testChartDeterminismStress():Void
  {
    final v1:String = haxe.Json.stringify(BenchmarkChart.buildVisual());
    final v2:String = haxe.Json.stringify(BenchmarkChart.buildVisual());
    check(v1 == v2, 'visual builds are byte-identical');
    final l1:String = haxe.Json.stringify(BenchmarkChart.buildLogic());
    final l2:String = haxe.Json.stringify(BenchmarkChart.buildLogic());
    check(l1 == l2, 'logic builds are byte-identical');
    // Different kinds must not collide.
    final g:String = haxe.Json.stringify(BenchmarkChart.build());
    check(v1 != g, 'visual diverges from gameplay');
    check(l1 != g, 'logic diverges from gameplay');
    check(v1 != l1, 'visual diverges from logic');
  }

  // ---- Kind model -------------------------------------------------------------

  static function testKindModel():Void
  {
    check(BenchmarkKindTools.id(GAMEPLAY) == 'phoenix-benchmark', 'gameplay id');
    check(BenchmarkKindTools.id(VISUAL) == 'phoenix-benchmark-visual', 'visual id');
    check(BenchmarkKindTools.id(LOGIC) == 'phoenix-benchmark-logic', 'logic id');
    check(BenchmarkKindTools.id(SYNTHETIC) == 'phoenix-benchmark-synthetic', 'synthetic id');
    check(BenchmarkKindTools.id(SUITE) == 'phoenix-benchmark-suite', 'suite id');
    check(BenchmarkKindTools.displayName(GAMEPLAY).length > 0, 'displayName non-empty');
    check(BenchmarkKindTools.shortLabel(VISUAL) == 'VISUAL', 'shortLabel visual');
    check(BenchmarkKindTools.isGameplayKind(GAMEPLAY) == true, 'gameplay is gameplay kind');
    check(BenchmarkKindTools.isGameplayKind(VISUAL) == true, 'visual is gameplay kind');
    check(BenchmarkKindTools.isGameplayKind(LOGIC) == true, 'logic is gameplay kind');
    check(BenchmarkKindTools.isGameplayKind(SYNTHETIC) == false, 'synthetic is not gameplay kind');
    check(BenchmarkKindTools.isGameplayKind(SUITE) == false, 'suite is not gameplay kind');
    check(BenchmarkKindTools.allGameplayKinds().length == 3, '3 gameplay kinds');
    check(BenchmarkKindTools.allKinds().length == 5, '5 kinds total');
  }

  static function testSuiteChartDispatch():Void
  {
    check(BenchmarkChart.buildKind(GAMEPLAY).song == 'phoenix-benchmark', 'buildKind gameplay');
    check(BenchmarkChart.buildKind(VISUAL).song == 'phoenix-benchmark-visual', 'buildKind visual');
    check(BenchmarkChart.buildKind(LOGIC).song == 'phoenix-benchmark-logic', 'buildKind logic');
    check(BenchmarkChart.buildKind(SYNTHETIC) == null, 'synthetic has no PlayState chart');
    check(BenchmarkChart.buildKind(SUITE) == null, 'suite has no PlayState chart');
    check(BenchmarkChart.buildKind(null).song == 'phoenix-benchmark', 'null defaults to gameplay');
  }

  static function testSynthetic():Void
  {
    check(FileSystem.exists('source/backend/BenchmarkSynthetic.hx'), 'BenchmarkSynthetic exists');
    check(FileSystem.exists('source/backend/BenchmarkKind.hx'), 'BenchmarkKind exists');
    check(FileSystem.exists('source/backend/BenchmarkKindTools.hx'), 'BenchmarkKindTools exists');
    final result = BenchmarkSynthetic.run();
    check(result != null, 'synthetic run produces a result');
    check(result.samples.length == 9, 'synthetic has 9 samples, got ' + result.samples.length);
    check(result.totalMs > 0, 'synthetic totalMs > 0');
    check(result.score > 0 && Math.isFinite(result.score), 'synthetic score finite > 0, got ' + result.score);
    for (s in result.samples)
    {
      check(s.iterations > 0, 'sample ' + s.name + ' iterations > 0');
      check(s.totalMs >= 0, 'sample ' + s.name + ' totalMs >= 0');
      check(s.avgMs >= 0 && Math.isFinite(s.avgMs), 'sample ' + s.name + ' avgMs finite');
      check(s.score >= 0, 'sample ' + s.name + ' score >= 0');
    }
    final report:String = BenchmarkSynthetic.formatReport(result);
    check(report.indexOf('Phoenix Engine - Synthetic') != -1, 'synthetic report header');
    check(report.indexOf('[SYNTHETIC RESULTS]') != -1, 'synthetic report section');
    check(report.indexOf('Overall score') != -1, 'synthetic report score');
    check(result.timestamp.length > 0, 'synthetic timestamp non-empty');
    final oneLine:String = BenchmarkSynthetic.oneLineSummary(result);
    check(oneLine.indexOf('Score') != -1, 'oneLineSummary contains Score');
  }

  // ---- Mod suppression -------------------------------------------------------

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

  // ---- Wiring ---------------------------------------------------------------

  static function testWiring():Void
  {
    final options:String = readRepo('source/options/OptimizationSubState.hx');
    check(options.indexOf('Device Benchmark') != -1, 'Options -> Optimization has the Device Benchmark row');
    check(occurrences(options, 'deviceBenchmark') >= 3, 'the row is wired to its handler');
    check(options.indexOf('backend.Benchmark.start()') != -1, 'accepting the confirm launches the benchmark');

    check(FileSystem.exists('source/backend/Benchmark.hx'), 'backend.Benchmark exists');
    check(FileSystem.exists('source/backend/BenchmarkChart.hx'), 'the fixed chart module exists');
    check(FileSystem.exists('assets/songs/phoenix-benchmark/Inst.ogg')
      && FileSystem.stat('assets/songs/phoenix-benchmark/Inst.ogg').size > 100 * 1024,
      'the bundled 60 s instrumental ships in the repo');
    check(FileSystem.exists('tools/generate_benchmark_inst.py'), 'the instrumental generator ships in tools/');

    final playState:String = readRepo('source/play/PlayState.hx');
    check(occurrences(playState, 'backend.Benchmark.active') >= 2, 'PlayState consults the benchmark flag');
    check(playState.indexOf('Benchmark.tick()') != -1, 'PlayState ticks the benchmark watchdog');
    check(playState.indexOf('Benchmark.exitRun()') != -1, 'destroy() always releases the mod suppression');

    final playback:String = readRepo('source/play/helpers/PlayStatePlayback.hx');
    final endSongAt:Int = playback.indexOf('public static function endSong');
    check(endSongAt != -1, 'endSong exists');
    check(playback.indexOf('backend.Benchmark.finish') != -1, 'endSong routes the benchmark to its report');

    final paths:String = readRepo('source/backend/Paths.hx');
    check(occurrences(paths, 'RecoveryBoot.modsDisabled()') >= 2, 'mod lookups go through the shared predicate');
    final mods:String = readRepo('source/backend/Mods.hx');
    check(mods.indexOf('RecoveryBoot.modsDisabled()') != -1, 'mod list parsing goes through the shared predicate');

    final results:String = readRepo('source/states/BenchmarkResultsState.hx');
    check(results.indexOf('Benchmark.reportText()') != -1, 'the results page renders the shared report text');
    check(results.indexOf('FrameProfiler') != -1 || results.indexOf('.log') != -1, 'the results page mentions the profiler export');

    final pause:String = readRepo('source/states/substates/PauseSubState.hx');
    check(pause.indexOf("remove('Restart Song')") != -1, 'the fixed benchmark cannot be restarted mid-run');

    final frameProfiler:String = readRepo('source/debug/FrameProfiler.hx');
    check(frameProfiler.indexOf('public static function exportLog') != -1, 'FrameProfiler.exportLog exists');
  }

  static function testWiringSuite():Void
  {
    final options:String = readRepo('source/options/OptimizationSubState.hx');
    // New hub + suite rows
    check(options.indexOf('Benchmarks') != -1 || options.indexOf('Benchmark Suite') != -1, 'Optimization has the suite entry');
    check(options.indexOf('Visual Benchmark') != -1, 'visual shortcut exists');
    check(options.indexOf('Logic Benchmark') != -1, 'logic shortcut exists');
    check(options.indexOf('Synthetic Benchmark') != -1, 'synthetic shortcut exists');
    check(options.indexOf('startVisual') != -1 || options.indexOf('VISUAL') != -1, 'visual row is wired');
    check(options.indexOf('startLogic') != -1 || options.indexOf('LOGIC') != -1, 'logic row is wired');
    check(options.indexOf('startSynthetic') != -1 || options.indexOf('SYNTHETIC') != -1, 'synthetic row is wired');

    final bench:String = readRepo('source/backend/Benchmark.hx');
    check(bench.indexOf('BenchmarkKind') != -1, 'Benchmark imports the kind');
    check(bench.indexOf('startVisual') != -1, 'Benchmark.startVisual exists');
    check(bench.indexOf('startLogic') != -1, 'Benchmark.startLogic exists');
    check(bench.indexOf('startSynthetic') != -1, 'Benchmark.startSynthetic exists');
    check(bench.indexOf('startSuite') != -1, 'Benchmark.startSuite exists');
    check(bench.indexOf('syntheticResult') != -1, 'Benchmark exposes syntheticResult');
    check(bench.indexOf('kind') != -1, 'Benchmark tracks kind');

    final chart:String = readRepo('source/backend/BenchmarkChart.hx');
    check(chart.indexOf('buildVisual') != -1, 'chart has buildVisual');
    check(chart.indexOf('buildLogic') != -1, 'chart has buildLogic');
    check(chart.indexOf('buildKind') != -1, 'chart has buildKind dispatch');
    check(chart.indexOf('VISUAL_SONG_NAME') != -1, 'visual song name constant');
    check(chart.indexOf('LOGIC_SONG_NAME') != -1, 'logic song name constant');
    check(chart.indexOf('SYNTHETIC') != -1, 'chart knows about synthetic');

    final kindFile:String = readRepo('source/backend/BenchmarkKind.hx');
    check(kindFile.indexOf('GAMEPLAY') != -1 && kindFile.indexOf('VISUAL') != -1 && kindFile.indexOf('LOGIC') != -1, 'kind has gameplay/visual/logic');
    check(kindFile.indexOf('SYNTHETIC') != -1 && kindFile.indexOf('SUITE') != -1, 'kind has synthetic/suite');

    final synth:String = readRepo('source/backend/BenchmarkSynthetic.hx');
    check(synth.indexOf('class BenchmarkSynthetic') != -1, 'synthetic class exists');
    check(synth.indexOf('function run') != -1, 'synthetic has run()');
    check(synth.indexOf('SyntheticResult') != -1, 'synthetic result type exists');
    check(synth.indexOf('formatReport') != -1, 'synthetic has formatReport');

    final menu:String = readRepo('source/states/BenchmarkMenuState.hx');
    check(menu.indexOf('BenchmarkMenuState') != -1, 'benchmark menu state exists');
    check(menu.indexOf('entries') != -1 || menu.indexOf('GAMEPLAY') != -1, 'menu lists kinds');

    final results:String = readRepo('source/states/BenchmarkResultsState.hx');
    check(results.indexOf('subtitleFor') != -1 || results.indexOf('BenchmarkKind') != -1, 'results screen knows about kinds');
    check(results.indexOf('M: benchmarks') != -1 || results.indexOf('BenchmarkMenuState') != -1, 'results links back to menu');

    check(FileSystem.exists('docs/BENCHMARK.md'), 'benchmark guide docs exist');
  }
}
