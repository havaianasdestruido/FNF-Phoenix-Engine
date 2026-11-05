import backend.DiagnosticsReport;
import backend.DiagnosticsReport.DiagnosticsFacts;

/**
 * Contract tests for `backend.DiagnosticsReport`.
 *
 * The reporter is Flixel- and Sys-free on purpose, so this spec runs in the
 * Haxe interpreter without any game haxelibs. It covers what a pasted block
 * must look like, what it must never leak, and the fail-safe edges (empty
 * logs, long stack frames, unknown hardware).
 *
 *     bash tests/haxe/run-diagnostics-report.sh
 */
class DiagnosticsReportSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function contains(haystack:String, needle:String, label:String):Void
  {
    if (haystack.indexOf(needle) == -1) throw label + ' (missing "' + needle + '" in:\n' + haystack + ')';
  }

  static function excludes(haystack:String, needle:String, label:String):Void
  {
    if (haystack.indexOf(needle) != -1) throw label + ' (leaked "' + needle + '" in:\n' + haystack + ')';
  }

  static function count(haystack:String, needle:String):Int
  {
    var total:Int = 0;
    var from:Int = 0;
    while (true)
    {
      final at:Int = haystack.indexOf(needle, from);
      if (at == -1) return total;
      total++;
      from = at + needle.length;
    }
  }

  static function repeat(text:String, times:Int):String
  {
    final out = new StringBuf();
    for (_ in 0...times) out.add(text);
    return out.toString();
  }

  static function longestLine(text:String):Int
  {
    var longest:Int = 0;
    for (line in text.split('\n'))
      if (line.length > longest) longest = line.length;
    return longest;
  }

  static function facts():DiagnosticsFacts
  {
    return {
      generatedAt: '2026-11-04 21:30:00',
      engineVersion: 'v0.0.1',
      jseVersion: '1.51.0',
      psychVersion: '0.6.3',
      commit: 'c7bb4a0',
      target: 'linux (hxcpp) release build',
      haxeVersion: 'Haxe 4.307',
      frameworkVersion: '9.4.1',
      runtimeLibVersion: '8.1.2',
      gameFrameworkVersion: '5.9.0',
      osName: 'Ubuntu',
      osVersion: '24.04',
      cpuModel: 'AMD Ryzen 5 3600',
      cpuVendor: 'AMD',
      cpuCores: '12 logical',
      ramTotal: '16GB',
      ramUsed: '5.2GB',
      gpuModel: 'NVIDIA GeForce RTX 3060',
      gpuVendor: 'NVIDIA',
      gpuDriver: '535.104.05',
      graphicsApi: 'OpenGL 4.6',
      renderer: 'NVIDIA Corporation',
      audioApi: 'OpenAL Soft | 1.23.1',
      heapUsed: '90.6MB',
      processRss: '210MB',
      display: '1280x720 (windowed)',
      framerate: '60',
      modCount: '2 enabled, 1 disabled',
      state: 'states.MainMenuState',
      vlogState: 'off (Options -> Misc)',
      installPath: '/home/bob/Games/Phoenix',
      savePath: '/home/bob/.local/share/company/funkin',
      mods: ['mymod (enabled)', 'other (enabled)', 'old (disabled)'],
      nonDefaultPrefs: ['downScroll=true', 'framerate=144'],
      logSource: 'last 2 lines of vlog/log.txt',
      logLines: ['[2026-11-04 21:29:58.001] [f0000001] [BOOT] system: GPU: NVIDIA GeForce RTX 3060',
                 '[2026-11-04 21:29:59.500] [f0000060] [FRAME] fps=60 frame=16.7ms']
    };
  }

  static function main():Void
  {
    hasEverySection();
    neverLeaksIdentity();
    redactionRules();
    keepsLogTailShort();
    clipsLongLines();
    formatsValues();
    diffsPrefs();
    handlesEmptyCollections();
    survivesNulls();
    reportShape();
  }

  /**
   * The block's shape: one marker line, the section order a reader scans for,
   * and no label that renames a library (this file stays dependency-free:
   * nothing here may reference a game haxelib).
   */
  static function reportShape():Void
  {
    final report:String = DiagnosticsReport.build(facts());
    final firstLine:String = report.split('\n')[0];
    check(firstLine == DiagnosticsReport.MARKER, 'the marker must be the first line: ' + firstLine);

    final order:Array<String> = ['[build]', '[hardware]', '[runtime]', '[paths]', '[mods]', '[prefs]', '[log]'];
    var at:Int = -1;
    for (section in order)
    {
      final found:Int = report.indexOf(section);
      check(found != -1, 'missing section ' + section);
      check(found > at, 'section ' + section + ' is out of order');
      at = found;
    }
    // Every stamped line stays pasteable: the block is nothing but short lines.
    final lines:Array<String> = report.split('\n');
    var longest:Int = 0;
    for (line in lines)
      if (line.length > longest) longest = line.length;
    check(longest <= DiagnosticsReport.MAX_LOG_LINE_CHARS + 2, 'longest line is ' + longest);
  }

  /** The block carries every fact a support ticket needs, in one paste. */
  static function hasEverySection():Void
  {
    final report:String = DiagnosticsReport.build(facts());
    check(report.indexOf(DiagnosticsReport.MARKER) == 0, 'the marker must be the first line');
    for (section in ['[build]', '[hardware]', '[runtime]', '[paths]', '[mods]', '[prefs]', '[log]'])
      contains(report, '\n' + section, 'missing section ' + section);

    // Required by TODO §19: version, commit, target, CPU/RAM, GPU/driver,
    // save path, mod list + order, non-default prefs, log tail.
    contains(report, 'engine: v0.0.1', 'engine version');
    contains(report, 'commit: c7bb4a0', 'commit hash');
    contains(report, 'target: linux (hxcpp) release build', 'target');
    contains(report, 'cpu: AMD Ryzen 5 3600', 'CPU');
    contains(report, 'ram_total: 16GB', 'RAM');
    contains(report, 'gpu: NVIDIA GeForce RTX 3060', 'GPU');
    contains(report, 'gpu_driver: 535.104.05', 'GPU driver');
    contains(report, 'save: /home/<user>/.local/share/company/funkin', 'save path');
    contains(report, 'downScroll=true', 'non-default pref');

    // Mods keep their load order.
    final mine:Int = report.indexOf('mymod (enabled)');
    final other:Int = report.indexOf('other (enabled)');
    final old:Int = report.indexOf('old (disabled)');
    check(mine != -1 && mine < other && other < old, 'mods must keep modsList order');
    contains(report, '#1: mymod (enabled)', 'mods are numbered');

    // The log tail is present, indented under [log].
    contains(report, '  [2026-11-04 21:29:59.500]', 'log tail');
    contains(report, '[log] last 2 lines of vlog/log.txt', 'log source and count');
  }

  /** Nothing in the block may identify the person or the machine's user. */
  static function neverLeaksIdentity():Void
  {
    final report:String = DiagnosticsReport.build(facts());
    excludes(report, 'bob', 'the user name must be redacted');
    excludes(report, '/home/bob', 'the home folder must be redacted');
    excludes(report, '/home/bob/Games', 'the install path must be redacted');
    contains(report, 'install: /home/<user>/Games/Phoenix', 'the install path keeps its shape');
  }

  /** The collector's known home folder is stripped verbatim, not just /home. */
  static function redactionRules():Void
  {
    check(DiagnosticsReport.redact('C:\\Users\\alice\\AppData\\Local\\Phoenix')
      == 'C:\\Users\\<user>\\AppData\\Local\\Phoenix', 'windows profile folder');
    check(DiagnosticsReport.redact('C:/Users/alice/data') == 'C:/Users/<user>/data',
      'windows folder with forward slashes');
    check(DiagnosticsReport.redact('C:\\Documents and Settings\\erin\\x')
      == 'C:\\Documents and Settings\\<user>\\x', 'XP profile folder');
    check(DiagnosticsReport.redact('D:\\Games\\Phoenix') == 'D:\\Games\\Phoenix',
      'a game folder outside a profile stays');
    check(DiagnosticsReport.redact('/home/carol/.local/share/x') == '/home/<user>/.local/share/x', 'unix home');
    check(DiagnosticsReport.redact('/Users/dave/Library') == '/Users/<user>/Library', 'macOS home');
    check(DiagnosticsReport.redact('/root/phoenix') == '/root/<user>', 'root home');
    check(DiagnosticsReport.redact('GITHUB_TOKEN=abc123', null) == 'GITHUB_TOKEN=<redacted>', 'env secret');
    check(DiagnosticsReport.redact('my_secret: hunter2') == 'my_secret: <redacted>', 'a secret spelled with a colon');
    check(DiagnosticsReport.redact('api_key: deadbeef') == 'api_key: <redacted>', 'lowercase api key');
    // Two secrets on one line must both go: the patterns are independent.
    check(DiagnosticsReport.redact('GITHUB_TOKEN=abc PASSWORD=hunter2')
      == 'GITHUB_TOKEN=<redacted> PASSWORD=<redacted>', 'two secrets on one line');
    // A key that merely *contains* a secret token is still a key.
    check(DiagnosticsReport.redact('MY_SESSION_ID=xyz') == 'MY_SESSION_ID=<redacted>', 'suffixed key');
    check(DiagnosticsReport.redact('see phoenix://menu/misc?mod=secret') == 'see phoenix://<redacted>',
      'deep link payload');
    check(DiagnosticsReport.redact('write to erin@example.com') == 'write to <email>', 'e-mail address');
    check(DiagnosticsReport.redact('cwd: /home/frank/Game', '/home/frank/Game') == 'cwd: <home>',
      'known home verbatim');
    check(DiagnosticsReport.redact('nothing to hide') == 'nothing to hide', 'plain text untouched');

    // A renamed profile folder outside the usual spellings is only caught by
    // the exact home directory the collector passes in.
    final renamed = facts();
    renamed.homeDirectory = 'D:\\Renders\\bob';
    renamed.logLines = ['[2026-11-04] [BOOT] cwd: D:\\Renders\\bob\\Phoenix'];
    final report = DiagnosticsReport.build(renamed);
    excludes(report, 'Renders', 'the known home folder must be redacted in the log too');
    contains(report, 'cwd: <home>\\Phoenix', 'the rest of the path keeps its shape');
  }

  /** The log tail is a bounded slice of the end of the log. */
  static function keepsLogTailShort():Void
  {
    final log = 'line1\nline2\nline3\nline4\n';
    final tail = DiagnosticsReport.tail(log, 2);
    check(tail.length == 2, 'two lines expected, got ' + tail.length);
    check(tail[0] == 'line3' && tail[1] == 'line4', 'the tail must be the end of the log');

    check(DiagnosticsReport.tail(log, 10).length == 4, 'shorter logs come back whole');
    check(DiagnosticsReport.tail(null, 5).length == 0, 'a missing log is empty');
    check(DiagnosticsReport.tail(log, 0).length == 0, 'zero lines means zero lines');

    // Half a stack frame reads like corruption: drop the cut first line.
    final cut = 'complete line\n  at Object.call (Foo.hx:12)\n  at Bar.baz (Bar.hx:3)';
    final picked = DiagnosticsReport.tail(cut, 2);
    check(picked.length == 1 && picked[0].indexOf('  at Bar.baz') == 0, 'drop the cut first line');
  }

  /** Long lines are clipped with a marker that says how much was dropped. */
  static function clipsLongLines():Void
  {
    final long = repeat('x', 500);
    final clipped = DiagnosticsReport.clip(long, 100);
    check(clipped.length <= 100, 'clip must respect the limit');
    contains(clipped, '(+' + (long.length - 100) + ' chars)', 'clip marker');
    check(DiagnosticsReport.clip('short', 100) == 'short', 'short lines stay');
    check(DiagnosticsReport.clip(null, 10) == '', 'null is empty');

    // The full block clips a runaway trace line rather than pasting 4 KB.
    final bloated = facts();
    bloated.logLines = ['[2026-11-04] ' + repeat('y', 2000)];
    final report = DiagnosticsReport.build(bloated);
    final longest:Int = longestLine(report);
    check(longest <= DiagnosticsReport.MAX_LOG_LINE_CHARS + 2,
      'the block must stay pasteable, longest line ' + longest);
  }

  /** Preference values are summarised, never dumped byte for byte. */
  static function formatsValues():Void
  {
    check(DiagnosticsReport.formatValue(true) == 'true', 'bool');
    check(DiagnosticsReport.formatValue(false) == 'false', 'false bool');
    check(DiagnosticsReport.formatValue(144) == '144', 'int');
    check(DiagnosticsReport.formatValue(1.5) == '1.5', 'float');
    check(DiagnosticsReport.formatValue('Default') == 'Default', 'string');
    check(DiagnosticsReport.formatValue(null) == 'null', 'null');
    // Note colours are nested arrays: only the shape is reported.
    final colours:Array<Dynamic> = [[1, 2, 3], [4, 5, 6]];
    check(DiagnosticsReport.formatValue(colours) == '[[3 items],[3 items]]', 'nested arrays are summarised');
    final offsets:Array<Dynamic> = [0, 10, -5, 1];
    check(DiagnosticsReport.formatValue(offsets) == '[0,10,-5,1]', 'flat arrays are listed');
  }

  /** Only values that differ from the engine default are listed. */
  static function diffsPrefs():Void
  {
    final changed = DiagnosticsReport.diffPrefs(['downScroll', 'framerate', 'noteSkin', 'arrowRGB'],
      [true, 144, 'Default', [[1, 2, 3]]],
      [false, 144, 'Default', [[1, 2, 3]]]);
    check(changed.length == 1, 'one changed pref expected, got ' + changed.length);
    check(changed[0] == 'downScroll=true', 'the changed pref is listed');

    // An array copied byte for byte is unchanged even though it is a new object.
    final copied = DiagnosticsReport.diffPrefs(['arrowRGB'], [[[9, 8, 7]]], [[[9, 8, 7]]]);
    check(copied.length == 0, 'equal arrays are not reported');

    // A JSON round trip turns an Int into a Float; that is not a change.
    final typeless = DiagnosticsReport.diffPrefs(['framerate'], [60.0], [60]);
    check(typeless.length == 0, 'Int and Float spellings of the same number match');

    final nothing = DiagnosticsReport.diffPrefs([], [], []);
    check(nothing.length == 0, 'no fields, no lines');
  }

  /** Empty mod/prefs/log lists still produce a valid, readable block. */
  static function handlesEmptyCollections():Void
  {
    final bare = facts();
    bare.mods = [];
    bare.nonDefaultPrefs = [];
    bare.logLines = [];
    final report = DiagnosticsReport.build(bare);
    contains(report, '(none enabled)', 'no mods');
    contains(report, '  (none)', 'no changed prefs');
    contains(report, '(no log)', 'no log');
    check(report.indexOf('\n\n\n') == -1, 'no triple blank lines in the block');

    final missing = facts();
    missing.mods = null;
    missing.nonDefaultPrefs = null;
    missing.logLines = null;
    final report2 = DiagnosticsReport.build(missing);
    check(report2.indexOf('[mods]') != -1, 'a missing list cannot crash the block');
  }

  /** Unknown hardware is reported as Unknown, never as null or empty. */
  static function survivesNulls():Void
  {
    final unknown = facts();
    unknown.gpuModel = null;
    unknown.gpuDriver = '';
    unknown.cpuModel = '   ';
    unknown.osVersion = null;
    final report = DiagnosticsReport.build(unknown);
    contains(report, 'gpu: Unknown', 'a missing GPU is Unknown');
    contains(report, 'gpu_driver: Unknown', 'an empty driver is Unknown');
    contains(report, 'cpu: Unknown', 'a whitespace CPU is Unknown');
    contains(report, 'os: Ubuntu', 'a missing OS version keeps the name');

    check(DiagnosticsReport.joinPair(null, null) == 'Unknown', 'pair of nulls');
    check(DiagnosticsReport.joinPair('Windows', null) == 'Windows', 'one half of a pair');
    check(DiagnosticsReport.joinPair('', '10.0.19045') == '10.0.19045', 'other half of a pair');
  }
}
