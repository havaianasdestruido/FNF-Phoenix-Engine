using StringTools;

import backend.LuaDiagnostics;
import backend.LuaDiagnostics.LuaDiagLevel;
import backend.LuaDiagnostics.LuaScanFs;

/**
 * Contract tests for `backend.LuaDiagnostics`, the "why does my Lua script
 * do nothing?" reporting (`docs/LUA_SCRIPT_DEBUGGING.md`).
 *
 * The class is dependency free on purpose, so its rules run here under
 * `haxe --interp`:
 *
 *   1. what is said and when: verbose-only lines, always-on warnings and
 *      errors, what reaches the screen;
 *   2. step 0: a build without the Lua VM that finds `.lua` files says so;
 *   3. discovery: which directory entries load, which are skipped and why;
 *   4. loading: syntax error vs. runtime error, the line an error points at;
 *   5. hooks: misspelt hook names, de-duplicated hook errors;
 *   6. the wiring in the engine sources that feeds all of the above.
 *
 * The runner executes it for the three kinds of build that exist, because
 * each reports differently: a target that cannot include Lua (no define), a
 * desktop build without the Lua VM (`-D desktop`, what a plain
 * `lime build windows` produces today) and a desktop build with it
 * (`-D desktop -D LUA_ALLOWED`). With `LUAJIT` pointing at a LuaJIT binary,
 * the error-position rules are also checked against messages produced by the
 * real runtime.
 *
 *     bash tests/haxe/run-lua-diagnostics.sh
 */
class LuaDiagnosticsSpec
{
  static inline var LUA_BUILD:Bool = #if LUA_ALLOWED true #else false #end;
  static inline var DESKTOP_BUILD:Bool = #if desktop true #else false #end;

  static var failures:Int = 0;
  static var checks:Int = 0;

  /** Every line the diagnostics printed since the last `reset()`. */
  static var printed:Array<String> = [];

  /** Every message the diagnostics put on screen since the last `reset()`. */
  static var shown:Array<{text:String, level:LuaDiagLevel}> = [];

  static function check(ok:Bool, label:String):Void
  {
    checks++;
    if (ok) return;
    failures++;
    Sys.println('  FAIL  $label');
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    check(actual == expected, '$label: expected "$expected", got "$actual"');
  }

  static function overlay(text:String, level:LuaDiagLevel):Void
  {
    shown.push({text: text, level: level});
  }

  /** Fresh session with captured output. */
  static function reset(verbose:Bool, label:String = '"Spec Song"'):Void
  {
    LuaDiagnostics.sink = function(line:String) printed.push(line);
    LuaDiagnostics.setVerbose(verbose, 'spec');
    LuaDiagnostics.beginSession(label, ['context line'], overlay);
    printed = [];
    shown = [];
  }

  static function printedContains(needle:String):Bool
  {
    for (line in printed) if (line.indexOf(needle) != -1) return true;
    return false;
  }

  static function shownContains(needle:String):Bool
  {
    for (entry in shown) if (entry.text.indexOf(needle) != -1) return true;
    return false;
  }

  static function main():Void
  {
    Sys.println('LuaDiagnosticsSpec (' + (DESKTOP_BUILD ? 'desktop' : 'non-desktop') + ' build '
      + (LUA_BUILD ? 'with' : 'without') + ' the Lua VM)');
    outputLevels();
    wrapping();
    buildSupport();
    classification();
    folderReview();
    songFolders();
    sourceInspection();
    loadFailures();
    errorPositions();
    securityHints();
    hookNames();
    hookErrors();
    summaries();
    wiring();
    realRuntime();

    if (failures > 0)
    {
      Sys.println('LuaDiagnosticsSpec: $failures of $checks checks FAILED');
      Sys.exit(1);
    }
    Sys.println('LuaDiagnosticsSpec: ok ($checks checks)');
  }

  // ---------------------------------------------------------------------
  // 1. Output
  // ---------------------------------------------------------------------

  static function outputLevels():Void
  {
    reset(false);
    LuaDiagnostics.log('step by step');
    equal(printed.length, 0, 'log() is silent unless verbose');

    LuaDiagnostics.warn('odd');
    LuaDiagnostics.error('broken');
    equal(printed.length, 2, 'warn() and error() always print');
    equal(printed[0], '[LuaDiag] WARNING: odd', 'warning line');
    equal(printed[1], '[LuaDiag] ERROR: broken', 'error line');
    equal(shown.length, 0, 'nothing is put on screen unless verbose');

    reset(true);
    LuaDiagnostics.log('step by step');
    equal(printed[0], '[LuaDiag] step by step', 'log() prints when verbose');
    LuaDiagnostics.warn('odd');
    LuaDiagnostics.error('broken');
    equal(shown.length, 2, 'verbose puts warnings and errors on screen');
    equal(shown[0].level, WARNING, 'warning level');
    equal(shown[1].level, ERROR, 'error level');
    check(shown[1].text.startsWith('[LuaDiag] ERROR: broken'), 'on-screen text carries the prefix');

    printed = [];
    LuaDiagnostics.emit('first\nsecond  ');
    equal(printed.length, 2, 'multi-line text is split');
    equal(printed[1], '[LuaDiag] second', 'every line is prefixed and right-trimmed');

    // Switching announces itself once and says whether Lua is in the build.
    printed = [];
    LuaDiagnostics.setVerbose(true, 'again');
    equal(printed.length, 0, 'setVerbose is silent when nothing changes');
    LuaDiagnostics.setVerbose(false);
    check(printedContains('verbose Lua logging OFF'), 'turning verbose off is announced');
    LuaDiagnostics.setVerbose(true, 'the reason');
    check(printedContains('verbose Lua logging ON (the reason)'), 'turning verbose on names the reason');
    check(printedContains(LuaDiagnostics.buildSupportLine()), 'turning verbose on states the build support');

    // A new session header carries the label, the build support and context.
    printed = [];
    LuaDiagnostics.beginSession('"Header"', ['working directory: /tmp'], overlay);
    check(printedContains('==== script load: "Header" ===='), 'verbose session header');
    check(printedContains('working directory: /tmp'), 'verbose session context');
    LuaDiagnostics.setVerbose(false);
    printed = [];
    LuaDiagnostics.beginSession('"Header"', ['working directory: /tmp'], overlay);
    equal(printed.length, 0, 'a quiet session prints no header');

    // The overlay belongs to the state that opened the session.
    reset(true);
    LuaDiagnostics.endSession();
    check(printedContains('==== script session over: "Spec Song", no hook errors ===='), 'a verbose session says when it is over');
    LuaDiagnostics.error('after the state is gone');
    equal(shown.length, 0, 'endSession() drops the overlay');

    // A state can be destroyed twice; the session is closed once.
    printed = [];
    LuaDiagnostics.endSession();
    equal(printed.length, 0, 'a second endSession() says nothing');

    // Optional scripts that do not exist: one line each, verbose only.
    reset(true);
    LuaDiagnostics.lookupMiss('stages/stage.lua', 'assets/stages/stage.lua');
    equal(printed[0], '[LuaDiag] lookup stages/stage.lua -> no such script (mod folders, then assets/stages/stage.lua)',
      'a missing optional script is named with the places that were searched');
    LuaDiagnostics.lookupMiss('characters/bf.lua', 'assets/characters/bf.lua', false);
    equal(printed[1], '[LuaDiag] lookup characters/bf.lua -> no such script (assets/characters/bf.lua)',
      'a build without mod folders does not claim to have searched them');
    printed = [];
    LuaDiagnostics.lookupMiss('custom_notetypes/.lua', 'assets/custom_notetypes/.lua');
    equal(printed.length, 0, 'the default (unnamed) note type is not reported as a missing script');
    reset(false);
    LuaDiagnostics.lookupMiss('stages/stage.lua', 'assets/stages/stage.lua');
    equal(printed.length, 0, 'lookups are only traced when verbose');

    // ...and one that exists in a build that cannot run it: always remembered, traced when verbose.
    LuaDiagnostics.lookupUnsupported('stages/stage.lua', 'mods/A/stages/stage.lua');
    equal(printed.length, 0, 'a script a build cannot run is not announced at the lookup when quiet');
    check(LuaDiagnostics.unsupportedScripts().contains('mods/A/stages/stage.lua'), 'but it is remembered for the summary');
    reset(true);
    LuaDiagnostics.lookupUnsupported('characters/bf.lua', 'mods/A/characters/bf.lua');
    equal(printed[0], '[LuaDiag] lookup characters/bf.lua -> mods/A/characters/bf.lua: NOT RUN (no Lua support in this build)',
      'verbose names the script at the lookup');
    LuaDiagnostics.lookupUnsupported('characters/bf.lua', 'mods/A/characters/bf.lua');
    equal(LuaDiagnostics.unsupportedScripts().length, 1, 'a script looked up twice is remembered once');
    reset(false);

    for (value in ['1', 'true', 'TRUE', ' yes ', 'on']) check(LuaDiagnostics.isTruthy(value), 'truthy: "$value"');
    for (value in ['0', 'false', '', 'off', 'no', 'maybe']) check(!LuaDiagnostics.isTruthy(value), 'not truthy: "$value"');
    check(!LuaDiagnostics.isTruthy(null), 'null is not truthy');
  }

  static function wrapping():Void
  {
    equal(LuaDiagnostics.wrap('short', 10), 'short', 'short text is untouched');
    equal(LuaDiagnostics.wrap('aaa bbb ccc ddd', 7), 'aaa bbb\nccc ddd', 'wraps at spaces');
    equal(LuaDiagnostics.wrap('one\ntwo three', 5), 'one\ntwo\nthree', 'keeps existing line breaks');
    equal(LuaDiagnostics.wrap('abcdefghij xy', 4), 'abcd\nefgh\nij\nxy', 'cuts a word longer than the width');
    equal(LuaDiagnostics.wrap(null, 10), '', 'null text');
    for (line in LuaDiagnostics.wrap(LuaDiagnostics.securityHint('My Mod', ['lua.os', 'lua.io']), LuaDiagnostics.SCREEN_COLUMNS).split('\n'))
      check(line.length <= LuaDiagnostics.SCREEN_COLUMNS, 'wrapped line fits the screen: ${line.length} columns');
  }

  // ---------------------------------------------------------------------
  // 2. Step 0: no Lua VM in the build
  // ---------------------------------------------------------------------

  static function buildSupport():Void
  {
    equal(LuaDiagnostics.luaCompiled(), LUA_BUILD, 'luaCompiled() follows LUA_ALLOWED');
    check(LuaDiagnostics.buildSupportLine().indexOf(LUA_BUILD ? 'includes the Lua VM' : 'does NOT include the Lua VM') != -1,
      'build support line');

    // Lua can be compiled in for desktop targets only (project.hxp adds
    // hxluajit there), so only a desktop build is told to rebuild.
    equal(LuaDiagnostics.luaBuildable(), DESKTOP_BUILD || LUA_BUILD, 'luaBuildable() follows the desktop define');

    final one:Array<String> = LuaDiagnostics.noLuaSupportLines(['mods/a/scripts/x.lua'], true);
    check(one[0].startsWith('1 Lua script found'), 'singular count');
    check(one.join('\n').indexOf('-DMODDING_LEVEL=1') != -1, 'names the build flag that fixes it');
    check(one.join('\n').indexOf('docs/LUA_SCRIPT_DEBUGGING.md') != -1, 'points at the guide');
    check(one.contains('  not run: mods/a/scripts/x.lua'), 'lists the script');

    final mobile:Array<String> = LuaDiagnostics.noLuaSupportLines(['mods/a/scripts/x.lua'], false);
    equal(mobile[0], one[0], 'the headline is the same on every platform');
    check(mobile.join('\n').indexOf('MODDING_LEVEL') == -1, 'a target that cannot include Lua is not told to rebuild');
    check(mobile.join('\n').indexOf('only include Lua in desktop builds') != -1, 'it is told where Lua is available');
    check(mobile.join('\n').indexOf('docs/LUA_SCRIPT_DEBUGGING.md') != -1, 'it still points at the guide');
    check(mobile.contains('  not run: mods/a/scripts/x.lua'), 'it still lists the script');

    equal(LuaDiagnostics.noLuaSupportLines(['x.lua']).join('\n'), (LuaDiagnostics.luaBuildable() ? one : mobile).join('\n').split('mods/a/scripts/').join(''),
      'the default wording follows the target');

    // The first three lines are what goes on screen.
    for (lines in [one, mobile])
      for (i in 0...3) check(('[LuaDiag] ' + lines[i]).length <= LuaDiagnostics.SCREEN_COLUMNS, 'on-screen line $i fits: ' + lines[i].length);

    final many:Array<String> = LuaDiagnostics.noLuaSupportLines([for (i in 0...12) 'mods/a/scripts/s$i.lua']);
    check(many[0].startsWith('12 Lua scripts found'), 'plural count');
    check(many.contains('  ... and 4 more'), 'long lists are capped');
  }

  // ---------------------------------------------------------------------
  // 3. Discovery
  // ---------------------------------------------------------------------

  static function classification():Void
  {
    equal(LuaDiagnostics.classify('script.lua', false, []), LOAD, 'plain script loads');
    equal(LuaDiagnostics.classify('script.lua', false, ['script.lua']), SHADOWED, 'same name from an earlier folder wins');
    equal(LuaDiagnostics.classify('script.lua', false, ['other.lua']), LOAD, 'another name does not shadow');
    equal(LuaDiagnostics.classify('script.lua', false, null), LOAD, 'null push list');
    equal(LuaDiagnostics.classify('Script.LUA', false, []), WRONG_EXTENSION, 'upper-case extension is not loaded');
    equal(LuaDiagnostics.classify('script.Lua', false, []), WRONG_EXTENSION, 'mixed-case extension is not loaded');
    equal(LuaDiagnostics.classify('script.lua.txt', false, []), WRONG_EXTENSION, 'hidden .txt extension');
    equal(LuaDiagnostics.classify('script.lua.bak', false, []), WRONG_EXTENSION, 'backup copy');
    equal(LuaDiagnostics.classify('script.lua~', false, []), WRONG_EXTENSION, 'editor backup');
    equal(LuaDiagnostics.classify('extra', true, []), SUBFOLDER, 'sub-folder');
    equal(LuaDiagnostics.classify('chart.json', false, []), IGNORED, 'unrelated file');
    equal(LuaDiagnostics.classify('script.py', false, []), IGNORED, 'another script language');
    equal(LuaDiagnostics.classify('lua', false, []), IGNORED, 'no extension');
    equal(LuaDiagnostics.classify('', false, []), IGNORED, 'empty name');
    equal(LuaDiagnostics.classify(null, false, []), IGNORED, 'null name');
  }

  /** An in-memory tree: directory path (no trailing slash) -> entry names. */
  static function fakeFs(tree:Map<String, Array<String>>, ignoreCase:Bool = false):LuaScanFs
  {
    function clean(path:String):String
    {
      while (path.length > 1 && path.endsWith('/')) path = path.substr(0, path.length - 1);
      return path;
    }
    function resolve(path:String):Null<String>
    {
      path = clean(path);
      if (tree.exists(path)) return path;
      if (ignoreCase) for (key in tree.keys()) if (key.toLowerCase() == path.toLowerCase()) return key;
      return null;
    }
    function isFile(path:String):Bool
    {
      path = clean(path);
      final slash:Int = path.lastIndexOf('/');
      if (slash < 0) return false;
      final parent:Null<String> = resolve(path.substr(0, slash));
      return parent != null && tree.get(parent).contains(path.substr(slash + 1));
    }
    return {
      exists: function(path:String) return resolve(path) != null || isFile(path),
      isDirectory: function(path:String) return resolve(path) != null,
      readDirectory: function(path:String)
      {
        final key:Null<String> = resolve(path);
        if (key == null) throw 'no such directory: $path';
        return tree.get(key).copy();
      }
    };
  }

  static function folderReview():Void
  {
    final fs:LuaScanFs = fakeFs([
      'mods/A/scripts' => ['hud.lua', 'Notes.LUA', 'old.lua.txt', 'extra', 'readme.md'],
      'mods/A/scripts/extra' => ['deep.lua', 'deeper.lua'],
      'mods/scripts' => ['hud.lua', 'other.lua'],
      'assets/shared/scripts' => []
    ]);

    // Quiet mode: only the misnamed files are worth a line.
    reset(false);
    LuaDiagnostics.beginScan('global scripts', ['mods/A/scripts/', 'mods/scripts/', 'assets/shared/scripts/']);
    LuaDiagnostics.reviewFolder('mods/A/scripts/', [], fs);
    equal(printed.length, 2, 'quiet review prints one warning per misnamed file');
    check(printedContains('WARNING: mods/A/scripts/Notes.LUA looks like a Lua script but is not loaded'), 'upper-case extension warning');
    check(printedContains('WARNING: mods/A/scripts/old.lua.txt looks like a Lua script but is not loaded'), 'double extension warning');
    equal(LuaDiagnostics.countOutcome(MISNAMED), 2, 'misnamed files are recorded');

    printed = [];
    LuaDiagnostics.reviewFolder('mods/scripts/', LUA_BUILD ? ['hud.lua'] : [], fs);
    LuaDiagnostics.reviewFolder('mods/missing/', [], fs);
    equal(printed.length, 0, 'a replaced script and a missing folder are not worth a line when quiet');
    equal(LuaDiagnostics.countOutcome(OVERRIDDEN), 1, 'replaced script is recorded');
    if (LUA_BUILD)
    {
      equal(LuaDiagnostics.countOutcome(UNSUPPORTED), 0, 'a Lua build has no unsupported scripts');
    }
    else
    {
      // The engine pushes no .lua names in such a build, so the review has to
      // work out by itself which same-named file a Lua build would have skipped.
      final unsupported:Array<String> = LuaDiagnostics.unsupportedScripts();
      equal(unsupported.length, 2, 'a build without Lua records the scripts a Lua build would have loaded');
      check(unsupported.contains('mods/A/scripts/hud.lua'), 'unsupported script path');
      check(unsupported.contains('mods/scripts/other.lua'), 'unsupported script in a later folder');
      check(!unsupported.contains('mods/scripts/hud.lua'), 'a script a Lua build would skip is not counted as one it cannot run');
    }

    // Verbose mode: every folder and every Lua-related entry.
    reset(true);
    LuaDiagnostics.beginScan('global scripts', ['mods/A/scripts/', 'mods/scripts/', 'mods/missing/']);
    check(printedContains('scan "global scripts": 3 folders'), 'scan header');
    LuaDiagnostics.reviewFolder('mods/A/scripts/', [], fs);
    LuaDiagnostics.reviewFolder('mods/scripts/', LUA_BUILD ? ['hud.lua'] : [], fs);
    LuaDiagnostics.reviewFolder('mods/missing/', [], fs);
    LuaDiagnostics.reviewFolder('assets/shared/scripts/', [], fs);
    check(printedContains('mods/A/scripts/ -> 5 entries, ' + (LUA_BUILD ? '1 Lua script to load' : '0 Lua scripts to load')), 'folder line');
    check(printedContains(LUA_BUILD ? '    hud.lua -> load' : '    hud.lua -> NOT RUN (no Lua support in this build)'), 'script decision');
    check(printedContains('    Notes.LUA -> SKIPPED'), 'misnamed decision');
    check(printedContains('extra/ -> not searched: script folders are read one level deep, so the 2 .lua files inside are not loaded'),
      'sub-folder note');
    check(printedContains('mods/missing/ -> does not exist'), 'missing folder line');
    check(printedContains('assets/shared/scripts/ -> 0 entries, 0 Lua scripts to load'), 'empty folder line');
    check(!printedContains('readme.md'), 'unrelated files are not listed');
    check(printedContains('    hud.lua -> SKIPPED: mods/A/scripts/hud.lua has the same file name and is searched first'), 'replaced decision names the winner');
    check(printedContains(LUA_BUILD ? '    other.lua -> load' : '    other.lua -> NOT RUN (no Lua support in this build)'),
      'second folder still handles its other script');

    // A folder that cannot be listed is reported, not thrown.
    final broken:LuaScanFs = {
      exists: function(path:String) return true,
      isDirectory: function(path:String) return false,
      readDirectory: function(path:String):Array<String> throw 'permission denied'
    };
    reset(false);
    LuaDiagnostics.reviewFolder('mods/locked/', [], broken);
    check(printedContains('WARNING: cannot list script folder mods/locked/: permission denied'), 'unreadable folder warning');

    equal(LuaDiagnostics.countLuaFiles('mods/A/scripts/', fs), 1, 'countLuaFiles counts exact .lua names only');
    equal(LuaDiagnostics.countLuaFiles('mods/missing/', fs), 0, 'countLuaFiles on a missing folder');
  }

  static function songFolders():Void
  {
    equal(LuaDiagnostics.looseSongKey('Transparency Test'), 'transparencytest', 'loose key drops spaces and case');
    equal(LuaDiagnostics.looseSongKey('transparency_test'), 'transparencytest', 'loose key drops underscores');
    equal(LuaDiagnostics.looseSongKey('transparency-test'), 'transparencytest', 'loose key drops dashes');
    equal(LuaDiagnostics.looseSongKey(null), '', 'null name');

    final misses:Array<String> = LuaDiagnostics.songFolderNearMisses('my-song', ['my-song', 'My Song', 'my_song', 'my-song-remix', 'other']);
    equal(misses.join('|'), 'My Song|my_song', 'near misses exclude the folder itself and other songs');
    equal(LuaDiagnostics.songFolderNearMisses('my-song', null).length, 0, 'null siblings');
    equal(LuaDiagnostics.songFolderNearMisses('---', ['___']).length, 0, 'a name without letters never matches');

    // The scripts sit in "My Song"; the engine reads "my-song".
    final wrong:LuaScanFs = fakeFs([
      'mods/A/data' => ['My Song', 'other'],
      'mods/A/data/My Song' => ['script.lua', 'my-song.json'],
      'mods/A/data/other' => ['x.lua']
    ]);
    reset(false);
    LuaDiagnostics.reviewSongFolders(['mods/A/data/my-song/', 'mods/data/my-song/'], wrong);
    equal(printed.length, 1, 'one warning for the misspelt song folder');
    check(printedContains('WARNING: mods/A/data/My Song/ has 1 Lua script but is not the folder this song reads'), 'misspelt folder warning');
    check(printedContains('Rename the folder to "my-song"'), 'the warning names the fix');

    // The folder exists under the right name too: the other spelling still holds unread scripts.
    final both:LuaScanFs = fakeFs([
      'mods/A/data' => ['my-song', 'my_song'],
      'mods/A/data/my-song' => ['a.lua'],
      'mods/A/data/my_song' => ['b.lua', 'c.lua']
    ]);
    reset(false);
    LuaDiagnostics.reviewSongFolders(['mods/A/data/my-song/'], both);
    check(printedContains('WARNING: mods/A/data/my_song/ has 2 Lua scripts'), 'a second spelling next to the real folder is reported');

    // A near miss without scripts is nobody's problem.
    final empty:LuaScanFs = fakeFs([
      'mods/A/data' => ['My Song'],
      'mods/A/data/My Song' => ['my-song.json']
    ]);
    reset(true);
    LuaDiagnostics.reviewSongFolders(['mods/A/data/my-song/'], empty);
    equal(printed.length, 0, 'a misspelt folder without Lua scripts is not reported');

    // Windows / macOS: "My-Song" answers to "my-song". It works here, so it
    // is only a note for people who ask for detail.
    final insensitive:LuaScanFs = fakeFs([
      'mods/A/data' => ['My-Song'],
      'mods/A/data/My-Song' => ['script.lua']
    ], true);
    reset(false);
    LuaDiagnostics.reviewSongFolders(['mods/A/data/my-song/'], insensitive);
    equal(printed.length, 0, 'a folder found through a case-insensitive file system is not a warning');
    reset(true);
    LuaDiagnostics.reviewSongFolders(['mods/A/data/my-song/'], insensitive);
    check(printedContains('is found only because this file system ignores letter case'), 'verbose mode notes the portability problem');
    check(!printedContains('WARNING'), 'the portability note is not a warning');

    // The shipped song folders must not trip the rule.
    reset(false);
    for (root in ['assets/shared/data', 'assets/data', 'mods/transparency-test/data'])
    {
      if (!sys.FileSystem.exists(root) || !sys.FileSystem.isDirectory(root)) continue;
      for (song in sys.FileSystem.readDirectory(root))
        if (sys.FileSystem.isDirectory('$root/$song')) LuaDiagnostics.reviewSongFolders(['$root/$song/']);
    }
    equal(printed.length, 0, 'no shipped song folder is flagged: ' + printed.join(' / '));
  }

  // ---------------------------------------------------------------------
  // 4. Loading
  // ---------------------------------------------------------------------

  static function sourceInspection():Void
  {
    final normal = LuaDiagnostics.inspectSource('function onCreate()\nend\n');
    equal(normal.problems.length, 0, 'normal source has no problems');
    equal(normal.lines, 3, 'line count');
    equal(normal.bytes, 24, 'byte count');

    equal(LuaDiagnostics.inspectSource('').problems.length, 1, 'empty file is a problem');
    equal(LuaDiagnostics.inspectSource('  \n\t\n').problems.length, 1, 'whitespace-only file is a problem');
    check(LuaDiagnostics.inspectSource('').problems[0].indexOf('empty') != -1, 'empty file message');
    check(LuaDiagnostics.inspectSource('f' + String.fromCharCode(0) + 'u').problems.join(' ').indexOf('NUL') != -1, 'NUL bytes are a problem');
    equal(LuaDiagnostics.inspectSource(null).problems.length, 1, 'unreadable source is a problem');

    final bom = LuaDiagnostics.inspectSource(String.fromCharCode(0xFEFF) + 'x = 1');
    equal(bom.problems.length, 0, 'a byte-order mark is not a problem');
    equal(bom.notes.length, 1, 'a byte-order mark is noted');

    // The cheap form keeps the problems and skips the measurements.
    final cheap = LuaDiagnostics.inspectSource('', false);
    equal(cheap.problems.length, 1, 'problems survive the cheap form');
    equal(cheap.bytes, 0, 'the cheap form does not measure');
  }

  static function loadFailures():Void
  {
    equal(LuaDiagnostics.statusName(0), 'ok', 'LUA_OK');
    equal(LuaDiagnostics.statusName(2), 'runtime error', 'LUA_ERRRUN');
    equal(LuaDiagnostics.statusName(3), 'syntax error', 'LUA_ERRSYNTAX');
    equal(LuaDiagnostics.statusName(4), 'out of memory', 'LUA_ERRMEM');
    equal(LuaDiagnostics.statusName(6), 'file could not be opened', 'LUA_ERRFILE');
    equal(LuaDiagnostics.statusName(42), 'status 42', 'unknown status');

    equal(LuaDiagnostics.loadFailureOutcome(false, 3), SYNTAX_ERROR, 'a chunk that did not compile is a syntax error');
    equal(LuaDiagnostics.loadFailureOutcome(true, 2), RUNTIME_ERROR, 'a chunk that compiled and raised is a runtime error');
    equal(LuaDiagnostics.loadFailureOutcome(false, 6), UNREADABLE, 'a file that could not be opened is unreadable');
    equal(LuaDiagnostics.loadFailureOutcome(false, 4), ENGINE_ERROR, 'out of memory while compiling');
    equal(LuaDiagnostics.loadFailureOutcome(true, 5), ENGINE_ERROR, 'error handler failure');

    final syntax:String = LuaDiagnostics.describeLoadFailure(false, 3, 'a.lua:3: unexpected symbol');
    check(syntax.startsWith('the file does not compile (syntax error): a.lua:3:'), 'syntax error wording: $syntax');
    final runtime:String = LuaDiagnostics.describeLoadFailure(true, 2, 'a.lua:9: attempt to call a nil value');
    check(runtime.startsWith('the file compiled, but its top-level code raised an error while running (runtime error): a.lua:9:'),
      'runtime error wording: $runtime');
    check(LuaDiagnostics.describeLoadFailure(false, 6, 'cannot open a.lua').startsWith('the file could not be opened: cannot open'),
      'unreadable wording');
    check(LuaDiagnostics.describeLoadFailure(false, 3, null).endsWith('<no message>'), 'missing message');
  }

  static function errorPositions():Void
  {
    equal(LuaDiagnostics.errorLine("mods/A/scripts/x.lua:12: unexpected symbol near '='"), 12, 'plain position');
    equal(LuaDiagnostics.errorLine("mods/A/scripts/x.lua:12: unexpected symbol near '='", 'mods/A/scripts/x.lua'), 12, 'position in the named script');
    equal(LuaDiagnostics.errorLine('C:/Games/Phoenix/mods/A/scripts/x.lua:7: boom', 'C:/Games/Phoenix/mods/A/scripts/x.lua'), 7, 'drive letter');
    equal(LuaDiagnostics.errorLine('C:\\Games\\mods\\x.lua:7: boom', 'C:/Games/mods/x.lua'), 7, 'backslashes');
    // LuaJIT shortens a long chunk name to "...tail".
    equal(LuaDiagnostics.errorLine('...ery/long/path/to/mods/A/scripts/x.lua:31: boom', 'some/very/long/path/to/mods/A/scripts/x.lua'), 31,
      'shortened chunk name');
    equal(LuaDiagnostics.errorLine('mods/B/other.lua:4: boom', 'mods/A/scripts/x.lua'), 0, 'an error in another file has no line here');
    equal(LuaDiagnostics.errorLine('[ModSecurity] blocked Lua call: os.execute'), 0, 'no position');
    equal(LuaDiagnostics.errorLine(null), 0, 'null message');
    equal(LuaDiagnostics.errorLine('x.lua:3: first\nstack traceback:\n\ty.lua:99: in main chunk', 'x.lua'), 3, 'only the first line counts');

    final source:String = 'local a = 1\r\nlocal b = = 2\r\n\tprint(a)\r\nreturn';
    final excerpt:Array<String> = LuaDiagnostics.sourceExcerpt(source, 2);
    equal(excerpt.length, 3, 'one line of context on each side');
    equal(excerpt[0], '       1 | local a = 1', 'context line, carriage return removed');
    equal(excerpt[1], '  >    2 | local b = = 2', 'the failing line is marked');
    equal(excerpt[2], '       3 |   print(a)', 'tabs become spaces');
    equal(LuaDiagnostics.sourceExcerpt(source, 1).length, 2, 'first line has no line before it');
    equal(LuaDiagnostics.sourceExcerpt(source, 4).length, 2, 'last line has no line after it');
    equal(LuaDiagnostics.sourceExcerpt(source, 0).length, 0, 'no position, no excerpt');
    equal(LuaDiagnostics.sourceExcerpt(source, 99).length, 0, 'a line past the end');
    equal(LuaDiagnostics.sourceExcerpt(null, 1).length, 0, 'null source');
    final nul:String = String.fromCharCode(0);
    equal(LuaDiagnostics.sourceExcerpt('f' + nul + 'u' + nul + 'n' + nul + '\n' + nul, 1).length, 0, 'a source with NUL bytes (UTF-16) is not quoted');
    final long:Array<String> = LuaDiagnostics.sourceExcerpt(StringTools.rpad('', 'x', 400), 1, 0);
    check(long[0].endsWith('...') && long[0].length < 200, 'a very long line is cut');
  }

  static function securityHints():Void
  {
    final inMod:String = LuaDiagnostics.securityHint('My Mod', ['lua.os', 'lua.os', 'network.url']);
    check(inMod.indexOf('"scriptSandboxAllowlist": ["lua.os", "network.url"]') != -1, 'allowlist snippet lists each rule once: $inMod');
    check(inMod.indexOf('mods/My Mod/pack.json') != -1, 'names the pack.json to edit');
    check(inMod.indexOf('"scriptSandbox": false') != -1, 'mentions the opt-out');
    check(inMod.indexOf('Mods menu (Mod Info)') != -1, 'mentions the per-mod switch a player can use');

    for (loose in [LuaDiagnostics.securityHint(null, ['lua.io']), LuaDiagnostics.securityHint('', ['lua.io'])])
    {
      check(loose.indexOf('loose script') != -1, 'a loose script is called out');
      check(loose.indexOf('"scriptSandboxAllowlist": ["lua.io"]') != -1, 'loose script still gets the snippet');
      check(loose.indexOf('Mods menu') == -1, 'a loose script has no Mod Info switch to point at');
    }

    // NUL bytes (a script saved as UTF-16) are not something to allow: the fix is the encoding.
    final encoding:String = LuaDiagnostics.securityHint('My Mod', ['security.binary-source']);
    check(encoding.indexOf('UTF-16') != -1 && encoding.indexOf('Save it again as UTF-8') != -1, 'NUL bytes: the hint is to re-save the file: $encoding');
    check(encoding.indexOf('scriptSandboxAllowlist') == -1, 'NUL bytes: no allowlist snippet, it would not make the file load');
    final mixed:String = LuaDiagnostics.securityHint('My Mod', ['security.binary-source', 'lua.os']);
    check(mixed.indexOf('Save it again as UTF-8') != -1, 'NUL bytes plus another finding: still the encoding hint');
    check(mixed.indexOf('"scriptSandboxAllowlist": ["lua.os"]') != -1, 'NUL bytes plus another finding: the snippet covers the other rule only: $mixed');
  }

  // ---------------------------------------------------------------------
  // 5. Hooks
  // ---------------------------------------------------------------------

  static function hookNames():Void
  {
    equal(LuaDiagnostics.hookSuggestion('onCreate'), null, 'a real hook needs no suggestion');
    equal(LuaDiagnostics.hookSuggestion('oncreate'), 'onCreate', 'wrong case');
    equal(LuaDiagnostics.hookSuggestion('OnUpdatePost'), 'onUpdatePost', 'wrong case, long name');
    equal(LuaDiagnostics.hookSuggestion('GoodNoteHit'), 'goodNoteHit', 'wrong case, note hook');
    equal(LuaDiagnostics.hookSuggestion('onUpdatPost'), null, 'a typo is not matched unless fuzzy');
    equal(LuaDiagnostics.hookSuggestion('onUpdatPost', true), 'onUpdatePost', 'missing letter');
    equal(LuaDiagnostics.hookSuggestion('onCreatee', true), 'onCreate', 'extra letter');
    equal(LuaDiagnostics.hookSuggestion('onBeetHit', true), 'onBeatHit', 'wrong letter');
    equal(LuaDiagnostics.hookSuggestion('onBeatHits', true), 'onBeatHit', 'trailing extra letter');
    equal(LuaDiagnostics.hookSuggestion('onEven', true), 'onEvent', 'missing last letter');
    equal(LuaDiagnostics.hookSuggestion('setupHud', true), null, 'an unrelated helper');
    equal(LuaDiagnostics.hookSuggestion('onUpdat3Pos', true), null, 'two edits away is not a match');
    equal(LuaDiagnostics.hookSuggestion('', true), null, 'empty name');
    equal(LuaDiagnostics.hookSuggestion(null, true), null, 'null name');

    final review = LuaDiagnostics.reviewFunctions(['spawnThing', 'onUpdate', 'oncreate', 'onCreatePost', 'onStepHitt'], true);
    equal(review.hooks.join(','), 'onCreatePost,onUpdate', 'hooks, sorted');
    equal(review.others.join(','), 'spawnThing', 'helpers');
    equal(review.nearMisses.length, 2, 'two misspelt hooks');
    equal(review.nearMisses[0].name + '>' + review.nearMisses[0].hook, 'onStepHitt>onStepHit', 'typo suggestion');
    equal(review.nearMisses[1].name + '>' + review.nearMisses[1].hook, 'oncreate>onCreate', 'case suggestion');
    equal(LuaDiagnostics.reviewFunctions(null).hooks.length, 0, 'null list');

    // A correctly spelt hook is never reported, even next to a similar one.
    for (hook in LuaDiagnostics.KNOWN_HOOKS)
      equal(LuaDiagnostics.reviewFunctions([hook], true).nearMisses.length, 0, 'hook $hook is not flagged');

    // The list is the one the engine dispatches and the template documents.
    final template:String = sys.io.File.getContent('docs/TemplateScript.lua');
    final documented:Array<String> = [];
    final pattern:EReg = ~/^function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(/;
    for (line in template.split('\n')) if (pattern.match(line)) documented.push(pattern.matched(1));
    check(documented.length > 30, 'the template documents hooks (found ${documented.length})');
    final engine:String = engineSources();
    check(engine.length > 100000, 'the engine sources were read (${engine.length} characters)');
    for (name in LuaDiagnostics.KNOWN_HOOKS)
    {
      check(documented.contains(name), 'docs/TemplateScript.lua documents the hook $name');
      check(namedIn(engine, name), 'the engine dispatches the hook $name');
    }

    // The template also defines functions that are not hooks: callbacks a
    // script registers by name itself (modCallback(beat, 'onModchartDrop')).
    // Those stay out of the list; a hook the engine dispatches may not.
    for (name in documented)
    {
      if (LuaDiagnostics.KNOWN_HOOKS.contains(name)) continue;
      final dispatched:Bool = namedIn(engine, name);
      check(!dispatched, 'KNOWN_HOOKS has the hook $name, which the engine dispatches and the template documents');
      if (!dispatched && !namedIn(template, name))
        Sys.println('  ..    NOTE: docs/TemplateScript.lua defines $name, but nothing in source/ calls a function by that name');
    }
  }

  /** Whether `text` mentions `name` as a quoted string, the way the engine names the hook it dispatches. */
  static function namedIn(text:String, name:String):Bool
  {
    return text.indexOf("'" + name + "'") != -1 || text.indexOf('"' + name + '"') != -1;
  }

  /** Every Haxe source of the engine in one string, without the diagnostics' own hook list. */
  static function engineSources():String
  {
    final all:StringBuf = new StringBuf();
    final pending:Array<String> = ['source'];
    while (pending.length > 0)
    {
      final dir:String = pending.pop();
      for (entry in sys.FileSystem.readDirectory(dir))
      {
        final path:String = '$dir/$entry';
        if (sys.FileSystem.isDirectory(path)) pending.push(path);
        else if (entry.endsWith('.hx') && path != 'source/backend/LuaDiagnostics.hx') all.add(sys.io.File.getContent(path));
      }
    }
    return all.toString();
  }

  static function hookErrors():Void
  {
    reset(false);
    final first:Null<String> = LuaDiagnostics.hookFailure('a.lua', 'onUpdate', 'a.lua:3: boom');
    check(first != null && first.startsWith('hook onUpdate of a.lua failed: a.lua:3: boom'), 'first occurrence is printed: $first');
    check(first != null && first.indexOf('luaDebugMode = true') != -1, 'the quiet line says how to see every occurrence');
    for (i in 0...500) equal(LuaDiagnostics.hookFailure('a.lua', 'onUpdate', 'a.lua:3: boom'), null, 'repeat $i stays quiet');
    check(LuaDiagnostics.hookFailure('a.lua', 'onUpdate', 'a.lua:4: other') != null, 'a different message is printed');
    check(LuaDiagnostics.hookFailure('a.lua', 'onBeatHit', 'a.lua:3: boom') != null, 'the same message from another hook is printed');
    check(LuaDiagnostics.hookFailure('b.lua', 'onUpdate', 'a.lua:3: boom') != null, 'the same message from another script is printed');
    equal(LuaDiagnostics.hookErrorCount(), 504, 'every occurrence is counted');

    // A script that formats a new message every frame cannot grow the table forever.
    reset(false);
    var printedLines:Int = 0;
    var overflowLine:Null<String> = null;
    for (i in 0...1000)
    {
      final line:Null<String> = LuaDiagnostics.hookFailure('a.lua', 'onUpdate', 'value $i');
      if (line == null) continue;
      printedLines++;
      if (line.indexOf('more than') != -1) overflowLine = line;
    }
    equal(printedLines, 257, '256 distinct errors plus one overflow notice');
    check(overflowLine != null, 'the overflow is announced');
    equal(LuaDiagnostics.hookErrorCount(), 1000, 'errors past the cap are still counted');

    // Verbose mode reminds at powers of ten and drops the hint.
    reset(true);
    final verboseFirst:Null<String> = LuaDiagnostics.hookFailure('a.lua', 'onUpdate', 'boom');
    check(verboseFirst != null && verboseFirst.indexOf('luaDebugMode') == -1, 'verbose line has no hint');
    final reminders:Array<Int> = [];
    for (count in 2...1001) if (LuaDiagnostics.hookFailure('a.lua', 'onUpdate', 'boom') != null) reminders.push(count);
    equal(reminders.join(','), '10,100,1000', 'verbose reminders at powers of ten');

    // A new song starts counting again.
    reset(false);
    check(LuaDiagnostics.hookFailure('a.lua', 'onUpdate', 'boom') != null, 'a new session prints the error again');
    equal(LuaDiagnostics.hookErrorCount(), 1, 'a new session restarts the count');

    printed = [];
    LuaDiagnostics.endSession();
    check(printedContains('"Spec Song": 1 Lua hook error in total, 1 distinct'), 'the session end sums up hook errors');
    printed = [];
    LuaDiagnostics.endSession();
    equal(printed.length, 0, 'the hook error total is reported once');
    reset(false);
    printed = [];
    LuaDiagnostics.endSession();
    equal(printed.length, 0, 'a quiet session without hook errors ends silently');
  }

  // ---------------------------------------------------------------------
  // Summary
  // ---------------------------------------------------------------------

  static function summaries():Void
  {
    // Nothing found: nothing to say.
    reset(false);
    LuaDiagnostics.reportSummary();
    equal(printed.length, 0, 'no scripts, no summary');
    equal(LuaDiagnostics.summaryLines().length, 0, 'no scripts, no lines');
    reset(true);
    LuaDiagnostics.reportSummary();
    check(printedContains('no Lua script was found for "Spec Song"'), 'verbose says that nothing was found');

    // Everything loaded: quiet unless verbose.
    reset(false);
    LuaDiagnostics.record(LOADED, 'a.lua');
    LuaDiagnostics.record(LOADED, 'b.lua');
    LuaDiagnostics.reportSummary();
    equal(printed.length, 0, 'a clean load is silent');
    check(!LuaDiagnostics.hasFailures(), 'no failures');
    reset(true);
    LuaDiagnostics.record(LOADED, 'a.lua');
    LuaDiagnostics.reportSummary();
    check(printedContains('Lua scripts for "Spec Song": 1 loaded'), 'verbose headline');
    equal(shown.length, 1, 'verbose puts the headline on screen');
    equal(shown[0].level, INFO, 'a clean headline is informational');

    // A failure is always summed up.
    reset(false);
    LuaDiagnostics.record(LOADED, 'a.lua');
    LuaDiagnostics.record(SYNTAX_ERROR, 'b.lua', 'b.lua:3: unexpected symbol');
    LuaDiagnostics.record(BLOCKED, 'c.lua', 'lua.os (line 4)');
    LuaDiagnostics.record(OVERRIDDEN, 'd.lua', 'replaced by e/d.lua (same file name, searched first)');
    LuaDiagnostics.record(MISNAMED, 'f.LUA', 'the file name does not end in exactly ".lua"');
    check(LuaDiagnostics.hasFailures(), 'failures are detected');
    LuaDiagnostics.reportSummary();
    equal(printed[0], '[LuaDiag] Lua scripts for "Spec Song": 1 loaded, 2 FAILED, 1 skipped (file name is not *.lua), 1 replaced by a same-named script',
      'headline with failures');
    check(printedContains('  FAILED  b.lua - syntax error: b.lua:3: unexpected symbol'), 'syntax error line');
    check(printedContains('  FAILED  c.lua - blocked by ModSecurity: lua.os (line 4)'), 'blocked line');
    check(printedContains('  SKIPPED f.LUA - the file name does not end in exactly ".lua"'), 'misnamed line');
    check(!printedContains('d.lua'), 'a replaced script is by design: not listed when quiet');
    equal(shown.length, 0, 'a quiet summary stays off the screen');
    check(LuaDiagnostics.summaryLines(true).join('\n').indexOf('SKIPPED d.lua') != -1, 'a replaced script is listed on request');

    // A replaced script alone is not a problem.
    reset(false);
    LuaDiagnostics.record(LOADED, 'a.lua');
    LuaDiagnostics.record(OVERRIDDEN, 'd.lua', 'replaced');
    LuaDiagnostics.reportSummary();
    equal(printed.length, 0, 'a replaced script alone does not trigger the summary');

    equal(LuaDiagnostics.sessionRecords().length, 2, 'records are kept for the session');
    LuaDiagnostics.beginSession('"Next"');
    equal(LuaDiagnostics.sessionRecords().length, 0, 'a new session forgets the previous one');

    // A build without Lua that found scripts: console every time, screen once per run.
    reset(false);
    LuaDiagnostics.record(UNSUPPORTED, 'mods/A/scripts/x.lua');
    LuaDiagnostics.record(UNSUPPORTED, 'mods/A/scripts/x.lua');
    LuaDiagnostics.record(UNSUPPORTED, 'mods/A/characters/bf.lua');
    equal(LuaDiagnostics.unsupportedScripts().length, 2, 'an unsupported script is listed once');
    check(!LuaDiagnostics.hasFailures(), 'a script the build cannot run is not a failure of the script');
    LuaDiagnostics.reportSummary();
    check(printedContains('ERROR: 2 Lua scripts found, but this build cannot run Lua'), 'no-Lua notice on the console');
    check(printedContains('  not run: mods/A/characters/bf.lua'), 'no-Lua notice lists the scripts');
    equal(shown.length, 1, 'no-Lua notice is put on screen even when quiet');
    equal(shown[0].level, ERROR, 'no-Lua notice is an error');
    check(shownContains(LuaDiagnostics.luaBuildable() ? '-DMODDING_LEVEL=1' : 'only include Lua in desktop builds'),
      'the on-screen notice says what can be done about it');
    equal(shown[0].text.split('\n').length, 3, 'the on-screen notice is one three-line message, in reading order');

    reset(false);
    LuaDiagnostics.record(UNSUPPORTED, 'mods/A/scripts/x.lua');
    LuaDiagnostics.reportSummary();
    check(printedContains('this build cannot run Lua'), 'the console notice repeats on the next song');
    equal(shown.length, 0, 'the on-screen notice does not repeat on the next song');

    reset(true);
    LuaDiagnostics.record(UNSUPPORTED, 'mods/A/scripts/x.lua');
    LuaDiagnostics.reportSummary();
    check(shownContains('this build cannot run Lua'), 'verbose shows the notice every time');
    LuaDiagnostics.setVerbose(false);
  }

  // ---------------------------------------------------------------------
  // 6. Wiring: the engine sources that feed the diagnostics
  // ---------------------------------------------------------------------

  static function count(haystack:String, needle:String):Int
  {
    return haystack.split(needle).length - 1;
  }

  static function wiring():Void
  {
    final lua:String = sys.io.File.getContent('source/psychlua/FunkinLua.hx');
    for (needle in [
      'LuaDiagnostics.beginLoad(scriptName',
      'diagSource(source, readProblem);',
      'diagBlocked(security.findings',
      'LuaDiagnostics.record(SANDBOX_FAILED, scriptName',
      'diagLoadFailed(compiled, result, resultStr, source);',
      'LuaDiagnostics.record(ENGINE_ERROR, scriptName',
      'diagLoaded(diagApi, diagStart);',
      'diagHookFailed(func, error);'
    ]) check(lua.indexOf(needle) != -1, 'FunkinLua reports: $needle');

    // The compile step and the run step must stay told apart.
    check(lua.indexOf('compiled = result == Lua.OK;') != -1, 'FunkinLua records whether the chunk compiled');
    // Hook dispatch runs every frame: the first-run log must sit behind the flag.
    check(lua.indexOf('if(LuaDiagnostics.verbose) diagFirstRun(func, result);') != -1, 'the per-call log is gated on the verbose flag');

    final play:String = sys.io.File.getContent('source/play/PlayState.hx');
    equal(count(play, 'LuaDiagnostics.reviewFolder(folder, filesPushed);'), 2, 'both folder scans are reviewed');
    equal(count(play, 'LuaDiagnostics.beginScan('), 2, 'both folder scans are announced');
    check(play.indexOf('LuaDiagnostics.reviewSongFolders(foldersToCheck);') != -1, 'the song scan checks for misspelt folders');
    final begin:Int = play.indexOf('LuaDiagnostics.beginSession(');
    final summary:Int = play.indexOf('LuaDiagnostics.reportSummary();');
    final createPost:Int = play.indexOf("callOnLuas('onCreatePost');");
    check(begin != -1 && summary != -1 && createPost != -1, 'PlayState opens a session, sums it up and calls onCreatePost');
    check(begin < summary && summary < createPost, 'the summary is printed after the scans and before onCreatePost');
    check(play.indexOf('LuaDiagnostics.endSession();') != -1, 'PlayState closes the session');

    // Every place that loads a script by name tells a build without Lua about it.
    equal(count(play, "startLuasOnFolder('"), 3, 'stage, note type and event scripts are loaded by name');
    equal(count(play, "noteUnsupportedLua('"), 3, 'each of them has a branch for builds without Lua');
    final helpers:String = sys.io.File.getContent('source/play/helpers/PlayStateScripts.hx');
    check(helpers.indexOf('LuaDiagnostics.lookupUnsupported(luaFile, path);') != -1, 'that branch reports the script it found');
    // A Safe Mode session without mods searches nothing under mods/: the verbose context says so.
    final context:String = helpers.substring(helpers.indexOf('function luaDiagContext()'));
    check(context.indexOf('if(backend.RecoveryBoot.disableMods)') != -1 && context.indexOf('Safe Mode started this session with all mods disabled') != -1,
      'the verbose context explains a Safe Mode session without mods');
    final characters:String = sys.io.File.getContent('source/play/helpers/PlayStateCharacters.hx');
    check(characters.indexOf("PlayStateScripts.noteUnsupportedLua('characters/") != -1, 'character scripts have a branch for builds without Lua');
    // The encoding hint is keyed on the rule id ModSecurity reports for NUL bytes.
    final security:String = sys.io.File.getContent('source/backend/ModSecurity.hx');
    check(security.indexOf("rule: '" + LuaDiagnostics.RULE_BINARY_SOURCE + "'") != -1,
      'ModSecurity still reports NUL bytes as ' + LuaDiagnostics.RULE_BINARY_SOURCE);
    // ...and a build with Lua traces the names that turned out not to exist.
    check(play.indexOf('LuaDiagnostics.lookupMiss(luaFile, Paths.getPreloadPath(luaFile)') != -1, 'a missing stage, note type or event script is traced');
    check(characters.indexOf("LuaDiagnostics.lookupMiss('characters/") != -1, 'a missing character script is traced');

    // On screen: a message is placed by its height, so the overlay has to format the text
    // before it measures it. Measured first, a new multi-line text lands above the screen.
    final overlay:String = helpers;
    final formatCalls:Array<String> = overlay.split('newText.setFormat(');
    equal(formatCalls.length - 1, count(overlay, 'newText.setPosition(10, 8 - newText.height);'), 'every overlay branch formats and positions its text');
    check(formatCalls.length > 1, 'the overlay formats its text');
    for (i in 1...formatCalls.length)
      equal(count(formatCalls[i], 'newText.setPosition(10, 8 - newText.height);'), 1, 'overlay branch $i measures the text after formatting it');
    check(play.indexOf('addTextToDebug(text, level == ERROR') != -1, 'PlayState puts diagnostics on the script overlay');

    // The verbose switch: option, saved preference, flags.ini and environment.
    final prefs:String = sys.io.File.getContent('source/backend/ClientPrefs.hx');
    check(prefs.indexOf('public static var luaVerbose:Bool = false;') != -1, 'ClientPrefs.luaVerbose exists and is off by default');
    final options:String = sys.io.File.getContent('source/options/MiscSettingsSubState.hx');
    check(options.indexOf("'luaVerbose'") != -1, 'Options -> Misc exposes luaVerbose');
    check(options.indexOf('LuaDiagnosticsSetup.sync()') != -1, 'changing the option applies immediately');
    final setup:String = sys.io.File.getContent('source/backend/LuaDiagnosticsSetup.hx');
    check(setup.indexOf('LuaDiagnostics.FLAG_VERBOSE') != -1 && setup.indexOf('LuaDiagnostics.ENV_VERBOSE') != -1,
      'the setup reads flags.ini and the environment');
    final main:String = sys.io.File.getContent('source/Main.hx');
    final initAt:Int = main.indexOf('backend.LuaDiagnosticsSetup.init(');
    check(initAt != -1, 'Main installs the diagnostics at boot');
    final initCall:String = initAt == -1 ? '' : main.substring(initAt, main.indexOf('\n', initAt));
    check(initCall.indexOf("ClientPrefs.readSavedBool('luaVerbose')") != -1, 'the saved verbose preference already covers the first song');
    // Safe Mode (backend.RecoveryBoot) shows its screen before any saved
    // preference is read, so that boot must not open the save here either.
    check(initCall.indexOf('RecoveryBoot.THRESHOLD ? false : ClientPrefs.readSavedBool(') != -1, 'a Safe Mode boot does not read the save this early');
    final flagsAt:Int = main.indexOf('backend.RuntimeFlags.load();');
    final vlogAt:Int = main.indexOf('backend.VLog.init(');
    check(flagsAt != -1 && vlogAt != -1 && initAt > flagsAt && initAt > vlogAt, 'the diagnostics start after flags.ini is loaded and the vlog is open');

    equal(LuaDiagnostics.FLAG_VERBOSE, 'scripts.verboseLua', 'flags.ini key');
    final flags:String = sys.io.File.getContent('flags.ini');
    final scriptsSection:Int = flags.indexOf('[scripts]');
    final key:Int = flags.indexOf('\nverboseLua = false');
    check(scriptsSection != -1 && key > scriptsSection, 'flags.ini documents [scripts] verboseLua, off by default');
    final nextSection:Int = flags.indexOf('\n[', scriptsSection + 1);
    check(nextSection == -1 || key < nextSection, 'verboseLua sits in the [scripts] section');

    // The build log explains whether Lua is in the build.
    final project:String = sys.io.File.getContent('project.hxp');
    check(project.indexOf('reportScriptSupport(moddingLevel, luaExplicit);') != -1, 'project.hxp reports script support');
    check(project.indexOf("info('Script support: Lua '") != -1, 'project.hxp prints the Script support line');
  }

  // ---------------------------------------------------------------------
  // Real LuaJIT (optional)
  // ---------------------------------------------------------------------

  static function runLua(luajit:String, driver:String, script:String):Array<String>
  {
    final process = new sys.io.Process(luajit, [driver, script]);
    final out:String = process.stdout.readAll().toString();
    final err:String = process.stderr.readAll().toString();
    final code:Int = process.exitCode();
    process.close();
    if (code != 0) return ['CRASH', err];
    final newline:Int = out.indexOf('\n');
    return newline < 0 ? [out.trim(), ''] : [out.substr(0, newline).trim(), out.substr(newline + 1).rtrim()];
  }

  /**
   * The messages the rules above parse come from LuaJIT. When one is
   * available, feed its real output through them: compile and run a chunk the
   * way `FunkinLua` does (same chunk-name convention) and check the phase,
   * the reported line and the hooks the script defined.
   */
  static function realRuntime():Void
  {
    final luajit:Null<String> = Sys.getEnv('LUAJIT');
    if (luajit == null || luajit.length == 0)
    {
      Sys.println('  ..    LUAJIT is not set: skipping the checks against the real runtime');
      return;
    }

    // An interpreter that cannot be started is skipped with a note, as run-lua-discovery.sh
    // does. Decided here so that the .sh, .bat and .ps1 launchers behave alike.
    var usable:Bool = false;
    try
    {
      final probe = new sys.io.Process(luajit, ['-e', 'io.write("probe-ok")']);
      final answer:String = probe.stdout.readAll().toString();
      usable = probe.exitCode() == 0 && answer == 'probe-ok';
      probe.close();
    }
    catch (e:Dynamic) {}
    if (!usable)
    {
      Sys.println('  ..    NOTE: LUAJIT=$luajit cannot be run: skipping the checks against the real runtime');
      return;
    }

    var temp:Null<String> = null;
    for (name in ['LUA_DIAGNOSTICS_TMP', 'TMPDIR', 'TEMP', 'TMP'])
    {
      temp = Sys.getEnv(name);
      if (temp != null && temp.length > 0 && sys.FileSystem.exists(temp)) break;
      temp = null;
    }
    if (temp == null) temp = '/tmp';
    final work:String = haxe.io.Path.removeTrailingSlashes(temp.split('\\').join('/')) + '/ld-' + Std.random(1000000);
    final deep:String = work + '/a/rather/long/folder/name/so/that/the/chunk/name/is/shortened/by/luajit';
    sys.FileSystem.createDirectory(deep);
    try
    {
      final driver:String = work + '/driver.lua';
      sys.io.File.saveContent(driver, [
        'local path = arg[1]',
        'local file = assert(io.open(path, "rb"))',
        'local source = file:read("*a")',
        'file:close()',
        'local before = {}',
        'for name, value in pairs(_G) do if type(name) == "string" and type(value) == "function" then before[name] = true end end',
        '-- FunkinLua: luaL_loadbuffer(lua, source, length, "@" .. scriptName), then lua_pcall',
        'local chunk, compileError = loadstring(source, "@" .. path)',
        'if not chunk then io.write("COMPILE\\n", compileError, "\\n") return end',
        'local ok, runError = pcall(chunk)',
        'if not ok then io.write("RUN\\n", tostring(runError), "\\n") return end',
        'local defined = {}',
        'for name, value in pairs(_G) do',
        '  if type(name) == "string" and type(value) == "function" and not before[name] then defined[#defined + 1] = name end',
        'end',
        'io.write("OK\\n", table.concat(defined, ","), "\\n")'
      ].join('\n'));

      function script(folder:String, name:String, lines:Array<String>):String
      {
        final path:String = '$folder/$name';
        sys.io.File.saveContent(path, lines.join('\n'));
        return path;
      }

      for (folder in [work, deep])
      {
        final where:String = folder == work ? 'short path' : 'long path';

        final syntaxPath:String = script(folder, 'syntax.lua', ['local a = 1', 'function onCreate()', '  local b = = 2', 'end']);
        final syntax:Array<String> = runLua(luajit, driver, syntaxPath);
        equal(syntax[0], 'COMPILE', '$where: a syntax error fails in the compile step');
        equal(LuaDiagnostics.errorLine(syntax[1], syntaxPath), 3, '$where: syntax error line from "${syntax[1]}"');
        equal(LuaDiagnostics.sourceExcerpt(sys.io.File.getContent(syntaxPath), LuaDiagnostics.errorLine(syntax[1], syntaxPath))[1],
          '  >    3 |   local b = = 2', '$where: the excerpt marks the offending line');

        final runtimePath:String = script(folder, 'runtime.lua', ['local a = 1', '', 'undefinedFunction(a)', 'function onCreate() end']);
        final runtime:Array<String> = runLua(luajit, driver, runtimePath);
        equal(runtime[0], 'RUN', '$where: an error in top-level code fails in the run step');
        equal(LuaDiagnostics.errorLine(runtime[1], runtimePath), 3, '$where: runtime error line from "${runtime[1]}"');
        equal(LuaDiagnostics.errorLine(runtime[1], folder + '/another.lua'), 0, '$where: the position is not applied to another script');
      }

      // LuaJIT really does shorten the long chunk name; otherwise the "..." rule is untested.
      final longSyntax:Array<String> = runLua(luajit, driver, deep + '/syntax.lua');
      check(longSyntax[1].startsWith('...'), 'LuaJIT shortens a long chunk name: "${longSyntax[1]}"');

      final hooksPath:String = script(work, 'hooks.lua', [
        'local function onSongStart() end -- local: invisible to the engine',
        'function onCreate() end',
        'function onupdate(elapsed) end',
        'function onBeatHitt() end',
        'function helper() end',
        'goodNoteHit = function() end'
      ]);
      final hooks:Array<String> = runLua(luajit, driver, hooksPath);
      equal(hooks[0], 'OK', 'the hook script loads');
      final review = LuaDiagnostics.reviewFunctions(hooks[1].split(','), true);
      equal(review.hooks.join(','), 'goodNoteHit,onCreate', 'hooks the script defined as globals');
      equal(review.others.join(','), 'helper', 'helpers the script defined');
      equal([for (miss in review.nearMisses) miss.name + '>' + miss.hook].join(','), 'onBeatHitt>onBeatHit,onupdate>onUpdate',
        'misspelt hooks the script defined');

      Sys.println('  ..    checked against ' + luajit);
    }
    catch (e:Dynamic)
    {
      check(false, 'real runtime checks raised: $e');
    }
    removeTree(work);
  }

  static function removeTree(path:String):Void
  {
    if (!sys.FileSystem.exists(path)) return;
    if (sys.FileSystem.isDirectory(path))
    {
      for (entry in sys.FileSystem.readDirectory(path)) removeTree('$path/$entry');
      sys.FileSystem.deleteDirectory(path);
    }
    else sys.FileSystem.deleteFile(path);
  }
}
