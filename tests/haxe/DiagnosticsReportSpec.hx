import backend.DiagnosticsReport;
import backend.VLog;
import debug.mem.GetTotalMemory;
import flixel.FlxG;

/**
 * Contract tests for `backend.DiagnosticsReport`, the text behind
 * `phoenix://diagnostics`.
 *
 * The report is the part of that route with real logic (it assembles the engine,
 * hardware, runtime, files, mods, settings and log sections), and it is the part
 * that must never change anything. It is compiled here against the small stubs
 * in `tests/haxe/stubs/diagnostics`, so the whole spec runs in the Haxe
 * interpreter without the game haxelibs:
 *
 *     bash tests/haxe/run-diagnostics-report.sh
 *
 * What is pinned: the layout a screenshot depends on, the bounded log tail, the
 * "not reported here" answers on targets that cannot know, the fact that a
 * throwing data source costs one row instead of the page, and that building a
 * report leaves the filesystem and the preferences alone.
 */
class DiagnosticsReportSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  /** Asserts the rendered report contains `needle`, verbatim. */
  static function contains(needle:String, label:String):Void
  {
    final text:String = DiagnosticsReport.build();
    check(text.indexOf(needle) != -1, '$label (missing ${quote(needle)})');
  }

  /** The report's own row shape, so a padding change fails here, not in a screenshot. */
  static function row(label:String, value:String):String
    return '  ' + StringTools.rpad(label, ' ', 15) + value;

  static function quote(value:String):String
    return '"' + StringTools.replace(value, '\n', '\\n') + '"';

  static function rowsOf(section:String):Array<String>
  {
    final rows:Array<String> = [];
    var inside:Bool = false;
    for (line in DiagnosticsReport.lines())
    {
      if (line.charAt(0) == '[')
      {
        if (inside) break;
        inside = (line == '[' + section + ']');
        continue;
      }
      if (inside && StringTools.trim(line).length > 0) rows.push(line);
    }
    return rows;
  }

  static function reset():Void
  {
    VLog.enabled = false;
    VLog.active = false;
    VLog.failNext = false;
    VLog.heapBytes = 234881024;
    VLog.lines = [];
    GetTotalMemory.current = 805306368;
    GetTotalMemory.peak = 1073741824;
    FlxG.game.ticks = 0;
    FlxG.width = 1280;
    FlxG.height = 720;
    FlxG.fullscreen = false;
    backend.Mods.enabled = [];
    backend.Mods.disabled = [];
    backend.Mods.invalidMods = [];
    backend.Mods.currentModDirectory = '';
  }

  static function main():Void
  {
    testStructureAndAlignment();
    testUptimeAndUnknownValues();
    testModsAreListedInLoadOrder();
    testLogTailIsBounded();
    testBrokenSourceCostsOneRow();
    testReportWritesNothing();
    Sys.println('DiagnosticsReportSpec passed');
  }

  static function testStructureAndAlignment():Void
  {
    reset();
    final text:String = DiagnosticsReport.build();
    final lines:Array<String> = text.split('\n');

    check(lines[0].indexOf('read-only') != -1, 'the page says what it is, in the first line');
    check((~/^\d{4}-\d{2}-\d{2}/).match(lines[1]), 'the snapshot is stamped with a date, got ' + quote(lines[1]));

    final headers:Array<String> = [];
    for (line in lines)
      if (line.charAt(0) == '[') headers.push(line);
    check(headers.join(' ') == '[BUILD] [HARDWARE] [RUNTIME] [FILES] [MODS] [SETTINGS] [RECENT LOG] [FOOTER]',
      'the sections support reads, in order, got: ' + headers.join(' '));

    // Every value column starts at the same offset, which is what makes the
    // page readable in a screenshot.
    contains(row('GPU driver', '535.104.05'), 'rows pad their label to the shared value column');
    for (row in rowsOf('HARDWARE'))
    {
      check(row.indexOf('  ') == 0, 'rows are indented by two spaces');
      check(row.length > 17, 'a row carries a value after the label column: ' + quote(row));
    }
    check(text.indexOf('\t') == -1, 'tabs would misalign the columns in the VCR font');
  }

  static function testUptimeAndUnknownValues():Void
  {
    reset();
    FlxG.game.ticks = 125000;
    contains(row('Uptime', '2m 05s'), 'seconds render as m s');
    FlxG.game.ticks = 3725000;
    contains(row('Uptime', '1h 02m'), 'long sessions render as h m');
    FlxG.game.ticks = 0;
    contains(row('Uptime', 'n/a'), 'no uptime reads as unknown, not 0s');

    // Targets without a native memory query must not print "0B" as a fact.
    VLog.heapBytes = -1;
    GetTotalMemory.current = 0;
    GetTotalMemory.peak = -1;
    debug.system.SystemInfo.ramBytes = 0;
    contains(row('Heap', 'not reported here'), 'heap unknown is labelled');
    contains(row('Total RAM', 'not reported here'), 'host RAM unknown is labelled');
    final runtime:Array<String> = rowsOf('RUNTIME');
    check(runtime.length > 0, 'the runtime section still renders with every query unavailable');

    VLog.heapBytes = 234881024;
    debug.system.SystemInfo.ramBytes = 17179869184;
  }

  static function testModsAreListedInLoadOrder():Void
  {
    reset();
    for (i in 0...12)
      backend.Mods.enabled.push('mod' + i);
    backend.Mods.disabled = ['sleepy'];
    backend.Mods.invalidMods = ['broken'];
    backend.Mods.currentModDirectory = 'mod11';

    final rows:Array<String> = rowsOf('MODS');
    check(rows[0].indexOf('Enabled') != -1 && rows[0].indexOf('12 of 13') != -1,
      'the count is the headline: ' + quote(rows[0]));
    check(rows[1] == '     1. mod0', 'load order is printed as the engine sees it');
    check(rows[10] == '     10. mod9', 'ten mods are listed by name');
    check(rows[11] == '     +2 more (the mods menu lists them all)', 'the rest collapses');
    contains('Rejected', 'rejected folders are called out');
    contains('mod11', 'the active mod directory is reported');
    contains(row('Disabled', 'sleepy'), 'disabled mods are named');

    reset();
    contains('no mods are enabled', 'an unmodded install says so instead of an empty block');
  }

  static function testLogTailIsBounded():Void
  {
    reset();
    contains('VLog is off', 'with the log off, the page explains how to turn it on');

    reset();
    VLog.enabled = true;
    VLog.active = true;
    for (i in 0...30)
      VLog.lines.push('FRAME line $i');
    VLog.lines.push('   ');
    final tail:Array<String> = rowsOf('RECENT LOG');
    check(tail.length == 10, 'only ten log lines are shown, got ' + tail.length);
    check(tail[9] == '  FRAME line 29', 'the newest line is last, got ' + quote(tail[9]));
    check(tail[0] == '  FRAME line 20', 'the tail starts ten lines from the end, got ' + quote(tail[0]));
    for (row in tail)
      check(StringTools.trim(row).length > 0, 'blank log lines are dropped');

    reset();
    VLog.enabled = true;
    VLog.active = true;
    contains('nothing logged yet', 'an empty log is reported as empty');

    // The page shows the log as the log stores it: redaction is VLog's policy
    // (backend.LogUtils), not something this report re-implements or skips.
    reset();
    VLog.enabled = true;
    VLog.active = true;
    VLog.lines = ['[00:00:01] wrote /home/phoenixsupport/projects/fnf/vlog/log.txt'];
    final rows:Array<String> = rowsOf('RECENT LOG');
    check(rows.length == 1, 'one line in, one line out');
    check(rows[0].indexOf('phoenixsupport') == -1, 'a username in a log line does not reach the page: ' + quote(rows[0]));
    check(rows[0].indexOf('[absolute path]') != -1, 'and the path arrives as the log policy left it: ' + quote(rows[0]));
    contains('wrote', 'the message itself is kept, so the line is still useful');

  }

  static function testBrokenSourceCostsOneRow():Void
  {
    reset();
    VLog.failNext = true;
    final text:String = DiagnosticsReport.build();
    check(text.indexOf('unavailable: ') != -1, 'a throwing data source becomes a row');
    check(text.indexOf('[BUILD]') != -1 && text.indexOf('[HARDWARE]') != -1
      && text.indexOf('[MODS]') != -1, 'one broken section does not take the page down');
    reset();
  }

  static function testReportWritesNothing():Void
  {
    reset();
    final logExisted:Bool = sys.FileSystem.exists(VLog.FILE);
    final dirExisted:Bool = sys.FileSystem.exists('vlog');
    final crashExisted:Bool = sys.FileSystem.exists('crash');
    final prefsBefore:String = [
      backend.ClientPrefs.framerate + '',
      backend.ClientPrefs.resolution,
      backend.ClientPrefs.deeplinkEnabled + ''
    ].join('/');

    for (i in 0...3)
      check(DiagnosticsReport.build().length > 0, 'the report renders');

    check(sys.FileSystem.exists(VLog.FILE) == logExisted, 'building a report never creates the log file');
    final prefsAfter:String = [
      backend.ClientPrefs.framerate + '',
      backend.ClientPrefs.resolution,
      backend.ClientPrefs.deeplinkEnabled + ''
    ].join('/');
    check(prefsBefore == prefsAfter, 'no preference moved while reading them');
    check(sys.FileSystem.exists('vlog') == dirExisted, 'no vlog/ directory is created');
    check(sys.FileSystem.exists('crash') == crashExisted, 'no crash/ directory is created');
  }
}
