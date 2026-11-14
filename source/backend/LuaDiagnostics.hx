package backend;

using StringTools;

/**
 * What a script-folder scan decides for one directory entry. Mirrors the
 * engine rule in `PlayState.create()`:
 * `file.endsWith('.lua') && !filesPushed.contains(file)`.
 */
enum abstract LuaScanVerdict(String) to String
{
  /** A `.lua` file the engine loads. */
  var LOAD = 'load';

  /** A `.lua` file skipped because a same-named file was found first in a higher-priority folder. */
  var SHADOWED = 'shadowed';

  /** Looks like a Lua script but does not end in exactly `.lua` (`.LUA`, `.lua.txt`, ...). */
  var WRONG_EXTENSION = 'wrong-extension';

  /** A sub-folder: script folders are read one level deep only. */
  var SUBFOLDER = 'subfolder';

  /** Not a Lua script. */
  var IGNORED = 'ignored';
}

/** How one script ended up, for the end-of-load summary. */
enum abstract LuaLoadOutcome(String) to String
{
  var LOADED = 'loaded';

  /** Rejected by the ModSecurity source scan before a Lua state existed. */
  var BLOCKED = 'blocked by ModSecurity';

  var UNREADABLE = 'unreadable';
  var SANDBOX_FAILED = 'sandbox bootstrap failed';
  var SYNTAX_ERROR = 'syntax error';
  var RUNTIME_ERROR = 'runtime error';
  var ENGINE_ERROR = 'engine error';

  /** The binary was built without the Lua VM. */
  var UNSUPPORTED = 'no Lua support in this build';

  /** Found by a folder scan but not loaded: the name does not end in exactly `.lua`. */
  var MISNAMED = 'misnamed';

  /** Found by a folder scan but not loaded: a same-named script in a higher-priority folder replaces it (by design). */
  var OVERRIDDEN = 'overridden';
}

/** Severity handed to the on-screen overlay. */
enum abstract LuaDiagLevel(Int) to Int
{
  var INFO = 0;
  var WARNING = 1;
  var ERROR = 2;
}

/** File-system access used by the folder review; injectable so the rules run under `haxe --interp`. */
typedef LuaScanFs =
{
  var exists:String->Bool;
  var isDirectory:String->Bool;
  var readDirectory:String->Array<String>;
}

typedef LuaLoadRecord =
{
  var script:String;
  var outcome:LuaLoadOutcome;
  var detail:String;
}

typedef LuaSourceFacts =
{
  var bytes:Int;
  var lines:Int;

  /** Worth a warning on their own: they explain a script that does nothing. */
  var problems:Array<String>;

  /** Harmless observations, verbose only. */
  var notes:Array<String>;
}

typedef LuaFunctionReview =
{
  /** Global functions whose name is an engine hook. */
  var hooks:Array<String>;

  /** Global functions that look like a misspelt hook and are therefore never called. */
  var nearMisses:Array<{name:String, hook:String}>;

  /** Every other global function the script defined. */
  var others:Array<String>;
}

/**
 * Makes the Lua script pipeline explain itself ("my Lua script does
 * nothing"). See `docs/LUA_SCRIPT_DEBUGGING.md`.
 *
 * Two levels:
 *
 *  - Always on: whatever makes a script silently not run is reported once,
 *    with the script name and the reason: no Lua VM in this build, an
 *    unreadable file, a syntax error vs. a top-level runtime error, the first
 *    occurrence of each hook error, a `.LUA` / `.lua.txt` file name, a song
 *    folder under the wrong spelling.
 *  - Verbose (opt in: Options -> Misc -> "Verbose Lua Logging", `flags.ini`
 *    `[scripts] verboseLua`, the `PHOENIX_LUA_VERBOSE=1` environment variable
 *    or a `-DLUA_VERBOSE` build): every folder that is scanned, every file
 *    decision, every load stage of every script, the hooks it defines and
 *    the first run of each. Warnings and errors are also put on screen.
 *
 * Every line starts with `[LuaDiag]` and goes to the console and, when VLog
 * is running, to `vlog/log.txt` (tag `LUA`).
 *
 * This class is deliberately free of engine, Flixel and Lua-binding
 * dependencies: it is compiled on every target (including builds without
 * `LUA_ALLOWED`, where it is what tells the player why nothing loads) and its
 * rules are exercised by `tests/haxe/LuaDiagnosticsSpec.hx` under
 * `haxe --interp`. The glue that feeds it lives in `psychlua.FunkinLua`,
 * `play.PlayState`, `play.helpers.PlayStateScripts` and
 * `backend.LuaDiagnosticsSetup`.
 */
class LuaDiagnostics
{
  public static inline final PREFIX:String = '[LuaDiag] ';

  /** Environment variable that forces verbose mode on (`1`, `true`, `yes`, `on`). */
  public static inline final ENV_VERBOSE:String = 'PHOENIX_LUA_VERBOSE';

  /** `flags.ini` key that forces verbose mode on. */
  public static inline final FLAG_VERBOSE:String = 'scripts.verboseLua';

  /** Columns an on-screen line may use: the debug overlay does not wrap by itself. */
  public static inline final SCREEN_COLUMNS:Int = 110;

  /** Stop remembering distinct hook errors past this many, so a script that formats a new message every frame cannot grow the table forever. */
  static inline final MAX_HOOK_ERRORS:Int = 256;

  /** How many of the `noLuaSupportLines` go on screen (the rest is console only). */
  static inline final NO_LUA_SCREEN_LINES:Int = 3;

  /**
   * Every hook the engine dispatches and `docs/TemplateScript.lua` documents.
   * Used only to recognise a misspelt hook (`oncreate`, `onUpdatepost`): hook
   * names are case-sensitive and a near miss is never called.
   * `LuaDiagnosticsSpec` checks each name against the template and against
   * the engine sources.
   */
  public static final KNOWN_HOOKS:Array<String> = [
    'onCreate', 'onCreatePost', 'onDestroy',
    'onSectionHit', 'onBeatHit', 'onStepHit', 'onUpdate', 'onUpdatePost',
    'onStartCountdown', 'onCountdownStarted', 'onCountdownTick', 'onSongStart', 'onEndSong',
    'onPause', 'onResume', 'onGameOver', 'onGameOverStart', 'onGameOverConfirm',
    'onNextDialogue', 'onSkipDialogue',
    'onSpawnNote', 'goodNoteHit', 'opponentNoteHit', 'goodNoteSkip', 'opponentNoteSkip',
    'noteMissPress', 'noteMiss', 'onGhostTap', 'onKeyPress', 'onKeyRelease',
    'onMoveCamera', 'onEvent', 'eventEarlyTrigger', 'onRecalculateRating', 'onUpdateScore',
    'onTweenCompleted', 'onTimerCompleted', 'onSoundFinished',
    'onCustomSubstateCreate', 'onCustomSubstateCreatePost', 'onCustomSubstateUpdate',
    'onCustomSubstateUpdatePost', 'onCustomSubstateDestroy'
  ];

  /** Whether the opt-in verbose level is on. Read on hot paths, so it is a plain field. */
  public static var verbose(default, null):Bool = false;

  /**
   * Where finished lines go. `null` prints to the console.
   * `LuaDiagnosticsSetup` installs a sink that also mirrors every line into
   * VLog.
   */
  public static var sink:Null<String->Void> = null;

  /** Puts a message in front of the player; set for the length of a session. */
  static var overlay:Null<String->LuaDiagLevel->Void> = null;

  static var records:Array<LuaLoadRecord> = [];
  static var sessionLabel:String = '';

  /** True between `beginSession()` and `endSession()`. */
  static var sessionOpen:Bool = false;
  static var loadCounter:Int = 0;

  /** File name -> first path that used it, for the scan in progress. */
  static var scanFirstPath:Map<String, String> = [];
  static var scanScope:String = '';

  static var hookErrorCounts:Map<String, Int> = [];
  static var hookErrorKeys:Int = 0;
  static var hookErrorOverflowReported:Bool = false;
  static var hookErrorTotal:Int = 0;

  /** The "no Lua in this build" notice was already put on screen during this run. */
  static var unsupportedShownOnScreen:Bool = false;

  // ---------------------------------------------------------------------
  // Output
  // ---------------------------------------------------------------------

  /** Whether this binary contains the Lua VM (`LUA_ALLOWED`). */
  public static inline function luaCompiled():Bool
  {
    return #if LUA_ALLOWED true #else false #end;
  }

  /**
   * Turn the verbose level on or off. `reason` names what asked for it
   * (the option, `flags.ini`, the environment) and is printed once.
   */
  public static function setVerbose(on:Bool, ?reason:String):Void
  {
    if (verbose == on) return;
    verbose = on;
    if (on)
    {
      emit('verbose Lua logging ON' + (reason == null || reason.length == 0 ? '' : ' ($reason)') + '. '
        + buildSupportLine());
    }
    else emit('verbose Lua logging OFF');
  }

  /** Whether a raw setting value (environment variable, ini value) means "on". */
  public static function isTruthy(value:Null<String>):Bool
  {
    if (value == null) return false;
    return switch (value.trim().toLowerCase())
    {
      case '1' | 'true' | 'yes' | 'on': true;
      default: false;
    }
  }

  /** Verbose-only line. */
  public static inline function log(message:String):Void
  {
    if (verbose) emit(message);
  }

  /** Always printed: something is suspicious but did not stop a script. On screen too while verbose. */
  public static function warn(message:String):Void
  {
    emit('WARNING: ' + message);
    if (verbose) show('WARNING: ' + message, WARNING);
  }

  /** Always printed: a script (or one of its hooks) did not run. On screen too while verbose. */
  public static function error(message:String):Void
  {
    emit('ERROR: ' + message);
    if (verbose) show('ERROR: ' + message, ERROR);
  }

  /** Print one line unconditionally, prefixed. Multi-line text keeps the prefix on every line. */
  public static function emit(message:String):Void
  {
    if (message == null) return;
    for (part in message.split('\n'))
    {
      var line:String = PREFIX + part.rtrim();
      if (sink != null)
      {
        sink(line);
        continue;
      }
      #if sys
      Sys.println(line);
      #else
      trace(line);
      #end
    }
  }

  /** Put a message on screen, if a session with an overlay is open. */
  static function show(message:String, level:LuaDiagLevel):Void
  {
    if (overlay == null) return;
    try
    {
      overlay(wrap(PREFIX + message, SCREEN_COLUMNS), level);
    }
    catch (e:Dynamic) {}
  }

  /**
   * Break `text` into lines of at most `width` columns at spaces (existing
   * line breaks are kept; a single longer word is cut).
   */
  public static function wrap(text:String, width:Int = SCREEN_COLUMNS):String
  {
    if (text == null) return '';
    if (width < 1) return text;
    var out:Array<String> = [];
    for (paragraph in text.split('\n'))
    {
      var line:String = '';
      for (word in paragraph.split(' '))
      {
        while (word.length > width)
        {
          if (line.length > 0)
          {
            out.push(line);
            line = '';
          }
          out.push(word.substr(0, width));
          word = word.substr(width);
        }
        if (line.length == 0) line = word;
        else if (line.length + 1 + word.length > width)
        {
          out.push(line);
          line = word;
        }
        else line += ' ' + word;
      }
      out.push(line);
    }
    return out.join('\n');
  }

  // ---------------------------------------------------------------------
  // Step 0: is Lua in this build at all?
  // ---------------------------------------------------------------------

  /** One line saying whether this binary can run `.lua` files. */
  public static function buildSupportLine():String
  {
    return luaCompiled()
      ? 'This build includes the Lua VM (LUA_ALLOWED).'
      : 'This build does NOT include the Lua VM (LUA_ALLOWED is off): .lua scripts cannot run.';
  }

  /**
   * Whether a rebuild can put the Lua VM into this target: `project.hxp`
   * adds the Lua bindings (hxluajit) for desktop targets only.
   */
  public static inline function luaBuildable():Bool
  {
    return #if (desktop || LUA_ALLOWED) true #else false #end;
  }

  /** The Lime target name of this build, for an example command line. */
  static inline function limeTarget():String
  {
    return #if windows 'windows' #elseif mac 'mac' #elseif linux 'linux' #else '<target>' #end;
  }

  /**
   * The message for a build that found `.lua` scripts it cannot run.
   * `scripts` are the files a Lua build would have loaded. The first
   * `NO_LUA_SCREEN_LINES` lines are short enough for the screen.
   * `buildable` (default: `luaBuildable()`) picks between "rebuild with this
   * flag" and "this platform has no Lua yet".
   */
  public static function noLuaSupportLines(scripts:Array<String>, ?buildable:Null<Bool>):Array<String>
  {
    if (buildable == null) buildable = luaBuildable();
    var count:Int = scripts == null ? 0 : scripts.length;
    var plural:String = count == 1 ? '' : 's';
    var lines:Array<String> = [
      '$count Lua script$plural found, but this build cannot run Lua (it was compiled without LUA_ALLOWED).',
      'The script$plural ' + (count == 1 ? 'is' : 'are') + ' not at fault: the Lua VM is not in this executable.'
    ];
    if (buildable)
    {
      lines.push('Rebuild with -DMODDING_LEVEL=1 (Lua) or -DMODDING_LEVEL=2 (Lua + Python).');
      lines.push('Example: lime test ' + limeTarget() + ' -DMODDING_LEVEL=1. The build log explains the choice on its '
        + '"Script support" line; see docs/LUA_SCRIPT_DEBUGGING.md, step 0.');
    }
    else
    {
      lines.push('The engine can only include Lua in desktop builds (Windows, Linux, macOS) for now.');
      lines.push('See docs/LUA_SCRIPT_DEBUGGING.md, step 0.');
    }
    if (scripts != null)
    {
      var shown:Int = 0;
      for (script in scripts)
      {
        if (shown == 8)
        {
          lines.push('  ... and ${count - shown} more');
          break;
        }
        lines.push('  not run: $script');
        shown++;
      }
    }
    return lines;
  }

  // ---------------------------------------------------------------------
  // Session
  // ---------------------------------------------------------------------

  /**
   * Start a new load session (one `PlayState.create()`); forgets the
   * previous one. `context` lines are printed in verbose mode. `overlay`
   * shows a message to the player and is dropped by `endSession()`.
   */
  public static function beginSession(label:String, ?context:Array<String>, ?overlay:String->LuaDiagLevel->Void):Void
  {
    records = [];
    sessionLabel = label == null ? '' : label;
    loadCounter = 0;
    scanFirstPath = [];
    scanScope = '';
    hookErrorCounts = [];
    hookErrorKeys = 0;
    hookErrorOverflowReported = false;
    hookErrorTotal = 0;
    sessionOpen = true;
    LuaDiagnostics.overlay = overlay;

    if (!verbose) return;
    emit('==== script load: $sessionLabel ====');
    emit(buildSupportLine());
    if (context != null) for (line in context) emit(line);
  }

  /**
   * The state that owned the session is going away: stop drawing on it and
   * sum up the hook errors. Safe to call again (a state can be destroyed
   * more than once); only the first call after `beginSession()` reports.
   */
  public static function endSession():Void
  {
    overlay = null;
    if (!sessionOpen) return;
    sessionOpen = false;
    if (hookErrorTotal > 0)
    {
      emit('$sessionLabel: $hookErrorTotal Lua hook error' + (hookErrorTotal == 1 ? '' : 's') + ' in total, $hookErrorKeys distinct '
        + '(the first occurrence of each is printed above).');
    }
    else log('==== script session over: $sessionLabel, no hook errors ====');
  }

  // ---------------------------------------------------------------------
  // Steps 1-2: discovery
  // ---------------------------------------------------------------------

  /**
   * Classify one entry of a scanned script folder exactly the way the engine
   * loop does. `alreadyPushed` holds the bare file names loaded from folders
   * scanned earlier.
   */
  public static function classify(file:String, isDirectory:Bool, alreadyPushed:Array<String>):LuaScanVerdict
  {
    if (file == null || file.length == 0) return IGNORED;
    if (file.endsWith('.lua'))
      return (alreadyPushed != null && alreadyPushed.contains(file)) ? SHADOWED : LOAD;
    if (isDirectory) return SUBFOLDER;

    var lower:String = file.toLowerCase();
    // .LUA / .Lua: the engine compares the extension case-sensitively.
    if (lower.endsWith('.lua')) return WRONG_EXTENSION;
    // script.lua.txt (hidden extensions on Windows), script.lua.bak, script.lua~
    if (lower.indexOf('.lua.') != -1 || lower.endsWith('.lua~')) return WRONG_EXTENSION;
    return IGNORED;
  }

  /**
   * Verbose: an optional script (stage, character, note type, event) was
   * looked up by name and does not exist. `relative` is the name inside a
   * mod, `fallback` the last path that was tried.
   */
  public static function lookupMiss(relative:String, fallback:String, modFolders:Bool = true):Void
  {
    if (!verbose || relative == null) return;
    // The default note type is the empty string, so every song looks for
    // "custom_notetypes/.lua"; nobody is expected to ship that file.
    if (relative == '.lua' || relative.endsWith('/.lua')) return;
    emit('lookup $relative -> no such script (' + (modFolders ? 'mod folders, then ' : '') + '$fallback)');
  }

  /**
   * A build without Lua found an optional script (stage, character, note
   * type, event) that a Lua build would have loaded by name. Remembered for
   * the summary; verbose mode also says so where the lookup happens.
   */
  public static function lookupUnsupported(relative:String, path:String):Void
  {
    log('lookup $relative -> $path: NOT RUN (no Lua support in this build)');
    record(UNSUPPORTED, path);
  }

  /** Announce a folder scan. Folders are searched in order and the first one wins a file-name clash. */
  public static function beginScan(scope:String, folders:Array<String>):Void
  {
    scanScope = scope == null ? '' : scope;
    scanFirstPath = [];
    if (!verbose || folders == null) return;
    emit('scan "$scanScope": ${folders.length} folder' + (folders.length == 1 ? '' : 's')
      + ', searched in this order (the first folder wins when two scripts share a file name):');
  }

  /**
   * Explain what a scan will do with one folder. Call it right before the
   * engine loop handles `folder`, with the names pushed so far.
   *
   * Always reported: a file that looks like a script but is not loaded
   * because of its name. Verbose: a line for every folder and every
   * Lua-related entry.
   */
  public static function reviewFolder(folder:String, alreadyPushed:Array<String>, ?fs:LuaScanFs):Void
  {
    if (fs == null) fs = defaultFs();
    if (fs == null || folder == null) return;

    var entries:Array<String> = null;
    try
    {
      if (!fs.exists(folder))
      {
        log('  $folder -> does not exist');
        return;
      }
      entries = fs.readDirectory(folder);
    }
    catch (e:Dynamic)
    {
      warn('cannot list script folder $folder: $e');
      return;
    }
    entries = entries == null ? [] : entries.copy();
    entries.sort(compareStrings);

    var loads:Int = 0;
    var notes:Array<String> = [];
    for (file in entries)
    {
      var path:String = folder + file;
      var verdict:LuaScanVerdict = classify(file, false, alreadyPushed);
      // Only stat what the answer depends on: scanned folders can be large.
      if (verdict == WRONG_EXTENSION || (verdict == IGNORED && verbose))
      {
        var isDir:Bool = false;
        try
        {
          isDir = fs.isDirectory(path);
        }
        catch (e:Dynamic) {}
        if (isDir) verdict = SUBFOLDER;
      }
      // A build without Lua pushes no .lua names, so only this scan's own
      // bookkeeping knows that an earlier folder already has this file name.
      if (verdict == LOAD && !luaCompiled() && scanFirstPath.exists(file)) verdict = SHADOWED;

      switch (verdict)
      {
        case LOAD:
          if (!scanFirstPath.exists(file)) scanFirstPath.set(file, path);
          if (luaCompiled())
          {
            loads++;
            notes.push('    $file -> load');
          }
          else
          {
            record(UNSUPPORTED, path);
            notes.push('    $file -> NOT RUN (no Lua support in this build)');
          }

        case SHADOWED:
          var winner:String = scanFirstPath.exists(file) ? scanFirstPath.get(file) : 'a folder searched earlier';
          record(OVERRIDDEN, path, 'replaced by $winner (same file name, searched first)');
          notes.push('    $file -> SKIPPED: $winner has the same file name and is searched first');

        case WRONG_EXTENSION:
          record(MISNAMED, path, 'the file name does not end in exactly ".lua"');
          notes.push('    $file -> SKIPPED: the name does not end in exactly ".lua"');
          warn('$path looks like a Lua script but is not loaded: the file name must end in exactly ".lua" '
            + '(lower case, with no second extension such as ".lua.txt").');

        case SUBFOLDER:
          if (verbose)
          {
            var nested:Int = countLuaFiles(path + '/', fs);
            if (nested > 0)
            {
              notes.push('    $file/ -> not searched: script folders are read one level deep, so the $nested .lua file'
                + (nested == 1 ? '' : 's') + ' inside ' + (nested == 1 ? 'is' : 'are') + ' not loaded from here');
            }
          }

        case IGNORED:
      }
    }

    if (!verbose) return;
    emit('  $folder -> ${entries.length} entr' + (entries.length == 1 ? 'y' : 'ies') + ', $loads Lua script'
      + (loads == 1 ? '' : 's') + ' to load');
    for (note in notes) emit(note);
  }

  /** Number of entries directly inside `folder` that the engine would treat as a Lua script. */
  public static function countLuaFiles(folder:String, ?fs:LuaScanFs):Int
  {
    if (fs == null) fs = defaultFs();
    if (fs == null || folder == null) return 0;
    var count:Int = 0;
    try
    {
      if (!fs.exists(folder)) return 0;
      for (file in fs.readDirectory(folder)) if (file.endsWith('.lua')) count++;
    }
    catch (e:Dynamic) {}
    return count;
  }

  /**
   * Collapse a song or folder name to the form two spellings of the same
   * song share (`Transparency Test`, `transparency_test`, `transparency-test`).
   */
  public static function looseSongKey(name:String):String
  {
    if (name == null) return '';
    var out:StringBuf = new StringBuf();
    var lower:String = name.toLowerCase();
    for (i in 0...lower.length)
    {
      var c:Int = lower.fastCodeAt(i);
      if ((c >= 'a'.code && c <= 'z'.code) || (c >= '0'.code && c <= '9'.code)) out.addChar(c);
    }
    return out.toString();
  }

  /**
   * Folders next to the expected song folder that are probably the same song
   * under another spelling. The engine only reads `data/<expected>/`, so a
   * script in one of these is not found.
   */
  public static function songFolderNearMisses(expected:String, siblings:Array<String>):Array<String>
  {
    var out:Array<String> = [];
    if (expected == null || siblings == null) return out;
    var key:String = looseSongKey(expected);
    if (key.length == 0) return out;
    for (sibling in siblings)
      if (sibling != null && sibling != expected && looseSongKey(sibling) == key) out.push(sibling);
    out.sort(compareStrings);
    return out;
  }

  /**
   * Look next to each song-script folder (`.../data/<song>/`) for a folder
   * that is the same song under another spelling and holds Lua scripts.
   *
   * The engine derives the folder name from the chart's song name (lower
   * case, spaces become dashes), so `data/My Song/` or `data/my_song/` is
   * not searched for the song "My Song". A folder that only differs by
   * letter case is found on Windows and macOS but not on Linux or Android.
   */
  public static function reviewSongFolders(folders:Array<String>, ?fs:LuaScanFs):Void
  {
    if (fs == null) fs = defaultFs();
    if (fs == null || folders == null) return;

    for (folder in folders)
    {
      if (folder == null) continue;
      var trimmed:String = folder.endsWith('/') ? folder.substr(0, folder.length - 1) : folder;
      var slash:Int = trimmed.lastIndexOf('/');
      if (slash < 0) continue;
      var parent:String = trimmed.substr(0, slash + 1);
      var expected:String = trimmed.substr(slash + 1);

      var siblings:Array<String> = null;
      var folderExists:Bool = false;
      try
      {
        if (!fs.exists(parent)) continue;
        siblings = fs.readDirectory(parent);
        folderExists = fs.exists(folder);
      }
      catch (e:Dynamic)
      {
        continue;
      }
      if (siblings == null) continue;

      // Listed under exactly the expected name: any other spelling is a
      // different folder. Not listed but "existing": a case-insensitive file
      // system resolved another spelling to it.
      var listedExactly:Bool = siblings.contains(expected);
      for (sibling in songFolderNearMisses(expected, siblings))
      {
        var siblingPath:String = parent + sibling;
        var count:Int = 0;
        try
        {
          if (!fs.isDirectory(siblingPath)) continue;
          count = countLuaFiles(siblingPath + '/', fs);
        }
        catch (e:Dynamic) {}
        if (count == 0) continue;

        var scripts:String = '$count Lua script' + (count == 1 ? '' : 's');
        if (!listedExactly && folderExists && sibling.toLowerCase() == expected.toLowerCase())
        {
          log('  note: $siblingPath/ is found only because this file system ignores letter case (the engine asks for '
            + '"$expected"). On Linux and Android its $scripts would not load; rename the folder to "$expected".');
          continue;
        }
        warn('$siblingPath/ has $scripts but is not the folder this song reads: the engine looks in $folder '
          + '(the song name in lower case, with spaces as dashes). Rename the folder to "$expected".');
      }
    }
  }

  // ---------------------------------------------------------------------
  // Steps 3-5: loading one script
  // ---------------------------------------------------------------------

  /** Announce a script load (verbose) and return its number in this session. */
  public static function beginLoad(script:String, origin:String):Int
  {
    loadCounter++;
    log('load #$loadCounter: $script ($origin)');
    return loadCounter;
  }

  /**
   * Facts about a source buffer. `problems` are always computed; the size
   * and the harmless `notes` only when `detailed`.
   */
  public static function inspectSource(source:Null<String>, detailed:Bool = true):LuaSourceFacts
  {
    var problems:Array<String> = [];
    var notes:Array<String> = [];
    if (source == null) return {bytes: 0, lines: 0, problems: ['the source could not be read'], notes: notes};

    if (source.trim().length == 0) problems.push('the file is empty, so it defines no hooks');
    if (source.indexOf(String.fromCharCode(0)) != -1)
      problems.push('the file contains NUL bytes (saved as UTF-16, or not a text file?). Save it as UTF-8 text');
    if (!detailed) return {bytes: 0, lines: 0, problems: problems, notes: notes};

    var bytes:Int = haxe.io.Bytes.ofString(source).length;
    var lines:Int = source.length == 0 ? 0 : source.split('\n').length;
    if (source.length > 0 && source.fastCodeAt(0) == 0xFEFF)
      notes.push('the file starts with a byte-order mark (harmless: LuaJIT skips it)');
    return {bytes: bytes, lines: lines, problems: problems, notes: notes};
  }

  /**
   * Name a `lua_pcall` / `luaL_loadbuffer` / `luaL_loadfile` status. The
   * numeric values are the Lua 5.1 / LuaJIT ABI constants (`LUA_YIELD` 1 ...
   * `LUA_ERRERR` 5, `LUA_ERRFILE` 6).
   */
  public static function statusName(status:Int):String
  {
    return switch (status)
    {
      case 0: 'ok';
      case 1: 'yield';
      case 2: 'runtime error';
      case 3: 'syntax error';
      case 4: 'out of memory';
      case 5: 'error in the error handler';
      case 6: 'file could not be opened';
      default: 'status $status';
    }
  }

  /**
   * Which outcome a failed chunk load maps to. `compiled` says whether the
   * chunk had already got past the Lua compiler when the status was produced.
   */
  public static function loadFailureOutcome(compiled:Bool, status:Int):LuaLoadOutcome
  {
    if (status == 6) return UNREADABLE;
    if (status == 4 || status == 5) return ENGINE_ERROR;
    return compiled ? RUNTIME_ERROR : SYNTAX_ERROR;
  }

  /** A sentence that tells a syntax error from top-level code that raised. */
  public static function describeLoadFailure(compiled:Bool, status:Int, message:String):String
  {
    var what:String = 'the file does not compile (${statusName(status)})';
    if (status == 6) what = 'the file could not be opened';
    else if (compiled) what = 'the file compiled, but its top-level code raised an error while running (${statusName(status)})';
    return what + ': ' + (message == null || message.length == 0 ? '<no message>' : message);
  }

  /**
   * The line number a Lua error message points at (`path:12: message`), or 0.
   *
   * With `scriptName`, the position only counts when it is in that file: an
   * error raised inside another chunk must not be shown against this
   * script's source. LuaJIT shortens long chunk names to `...tail`, so the
   * file is matched by the end of its path.
   */
  public static function errorLine(message:String, ?scriptName:String):Int
  {
    if (message == null) return 0;
    var pattern:EReg = ~/^([^\n]*?):(\d+): /;
    if (!pattern.match(message)) return 0;
    var line:Null<Int> = Std.parseInt(pattern.matched(2));
    if (line == null) return 0;
    if (scriptName == null) return line;

    var chunk:String = pattern.matched(1).split('\\').join('/');
    var wanted:String = scriptName.split('\\').join('/');
    if (chunk.startsWith('...')) chunk = chunk.substr(3);
    if (chunk.length == 0) return 0;
    return wanted.endsWith(chunk) || chunk.endsWith(wanted) ? line : 0;
  }

  /** The lines around `line` (1-based) of `source`, numbered, with a marker on the line itself. */
  public static function sourceExcerpt(source:Null<String>, line:Int, context:Int = 1):Array<String>
  {
    var out:Array<String> = [];
    if (source == null || line < 1) return out;
    // Not text (UTF-16, a binary file): quoting it would print garbage, and
    // the NUL-byte warning has already said what is wrong with the file.
    if (source.indexOf(String.fromCharCode(0)) != -1) return out;
    var lines:Array<String> = source.split('\n');
    if (line > lines.length) return out;
    var from:Int = line - context < 1 ? 1 : line - context;
    var to:Int = line + context > lines.length ? lines.length : line + context;
    for (number in from...to + 1)
    {
      var text:String = lines[number - 1];
      if (text.endsWith('\r')) text = text.substr(0, text.length - 1);
      text = text.split('\t').join('  ');
      if (text.length > 160) text = text.substr(0, 160) + '...';
      out.push((number == line ? '  > ' : '    ') + StringTools.lpad('' + number, ' ', 4) + ' | ' + text);
    }
    return out;
  }

  /** ModSecurity's rule id for a script that contains NUL bytes. */
  public static inline var RULE_BINARY_SOURCE:String = 'security.binary-source';

  /**
   * How to get past a ModSecurity block. `modFolder` is `null` for a loose
   * script (directly under `mods/scripts`, `mods/data/<song>`, ...), which has
   * no `pack.json` to carry an allowlist and no Mod Info switch in the Mods menu.
   */
  public static function securityHint(modFolder:Null<String>, rules:Array<String>):String
  {
    var unique:Array<String> = [];
    if (rules != null) for (rule in rules) if (rule != null && !unique.contains(rule)) unique.push(rule);

    // NUL bytes are an encoding problem, not something to allow: LuaJIT
    // could not compile such a file either.
    var encoding:String = '';
    if (unique.remove(RULE_BINARY_SOURCE))
    {
      encoding = 'The file contains NUL bytes, which Lua source text never does: it was most likely saved as UTF-16 '
        + '("Unicode" in some Windows editors). Save it again as UTF-8 so the engine can read it.';
      if (unique.length == 0) return encoding;
      encoding += ' For the other findings: ';
    }

    var quoted:String = [for (rule in unique) '"$rule"'].join(', ');
    if (modFolder == null || modFolder.length == 0)
    {
      return encoding + 'This is a loose script (not inside a mod folder), so there is no pack.json to allow [$quoted]. '
        + 'Move it into a mod folder (mods/<your mod>/...) and add "scriptSandboxAllowlist": [$quoted] to that '
        + 'mod\'s pack.json, or remove the flagged code.';
    }
    return encoding + 'To run it anyway add "scriptSandboxAllowlist": [$quoted] to mods/$modFolder/pack.json '
      + '(or "scriptSandbox": false to turn the scan off for this mod), or remove the flagged code. '
      + 'A player who trusts the mod can also turn ModSecurity off for it in the Mods menu (Mod Info). '
      + 'The scan matches text, so it also fires on a string or a trailing comment.';
  }

  // ---------------------------------------------------------------------
  // Step 6: hooks
  // ---------------------------------------------------------------------

  /**
   * The hook a global function was probably meant to be, or `null`.
   *
   * A name that differs from a hook only by letter case is always a match.
   * With `fuzzy`, so is a name one edit away (one letter missing, added or
   * wrong).
   */
  public static function hookSuggestion(name:String, fuzzy:Bool = false):Null<String>
  {
    if (name == null || name.length == 0 || KNOWN_HOOKS.contains(name)) return null;
    var lower:String = name.toLowerCase();
    for (hook in KNOWN_HOOKS) if (hook.toLowerCase() == lower) return hook;
    if (!fuzzy) return null;
    for (hook in KNOWN_HOOKS) if (editDistanceAtMostOne(lower, hook.toLowerCase())) return hook;
    return null;
  }

  /** Sort the global functions a script defined into hooks, misspelt hooks and helpers. */
  public static function reviewFunctions(names:Array<String>, fuzzy:Bool = false):LuaFunctionReview
  {
    var review:LuaFunctionReview = {hooks: [], nearMisses: [], others: []};
    if (names == null) return review;
    var sorted:Array<String> = names.copy();
    sorted.sort(compareStrings);
    for (name in sorted)
    {
      if (KNOWN_HOOKS.contains(name))
      {
        review.hooks.push(name);
        continue;
      }
      var hook:Null<String> = hookSuggestion(name, fuzzy);
      if (hook != null) review.nearMisses.push({name: name, hook: hook});
      else review.others.push(name);
    }
    return review;
  }

  static function editDistanceAtMostOne(a:String, b:String):Bool
  {
    var la:Int = a.length;
    var lb:Int = b.length;
    if (la == lb)
    {
      var differences:Int = 0;
      for (i in 0...la) if (a.fastCodeAt(i) != b.fastCodeAt(i) && ++differences > 1) return false;
      return differences == 1;
    }
    if (la - lb != 1 && lb - la != 1) return false;
    var longer:String = la > lb ? a : b;
    var shorter:String = la > lb ? b : a;
    var i:Int = 0;
    var j:Int = 0;
    var skipped:Bool = false;
    while (i < longer.length && j < shorter.length)
    {
      if (longer.fastCodeAt(i) == shorter.fastCodeAt(j))
      {
        i++;
        j++;
        continue;
      }
      if (skipped) return false;
      skipped = true;
      i++;
    }
    return true;
  }

  /**
   * Count one failed hook call and say whether it should be printed.
   *
   * Hook errors are otherwise only visible when the script itself sets
   * `luaDebugMode = true`, so a hook that throws on every frame looks exactly
   * like a hook that is never called. The first occurrence of each distinct
   * `(script, hook, message)` is printed; repeats are only counted (and, in
   * verbose mode, reported again at the 10th, 100th, 1000th... occurrence).
   *
   * @return the line to print, or `null` when this occurrence stays quiet.
   */
  public static function hookFailure(script:String, hook:String, message:String):Null<String>
  {
    hookErrorTotal++;
    var key:String = script + '\n' + hook + '\n' + message;
    var count:Int = 1;
    if (hookErrorCounts.exists(key))
    {
      count = hookErrorCounts.get(key) + 1;
      hookErrorCounts.set(key, count);
    }
    else
    {
      if (hookErrorKeys >= MAX_HOOK_ERRORS)
      {
        if (hookErrorOverflowReported) return null;
        hookErrorOverflowReported = true;
        return 'more than $MAX_HOOK_ERRORS distinct Lua hook errors in this song; further new ones are counted but not printed.';
      }
      hookErrorKeys++;
      hookErrorCounts.set(key, 1);
    }

    if (count == 1)
    {
      return 'hook $hook of $script failed: $message'
        + (verbose ? '' : ' (printed once; set luaDebugMode = true in the script to see every occurrence in game)');
    }
    if (verbose && isPowerOfTen(count)) return 'hook $hook of $script has now failed $count times with: $message';
    return null;
  }

  static function isPowerOfTen(value:Int):Bool
  {
    if (value < 10) return false;
    while (value % 10 == 0) value = Std.int(value / 10);
    return value == 1;
  }

  /** Total hook errors since `beginSession`, including the repeats that were not printed. */
  public static function hookErrorCount():Int
  {
    return hookErrorTotal;
  }

  // ---------------------------------------------------------------------
  // Summary
  // ---------------------------------------------------------------------

  /** Remember how one script ended up. */
  public static function record(outcome:LuaLoadOutcome, script:String, ?detail:String):Void
  {
    if (script == null) script = '';
    // A character or event script is looked up once per use; a build that
    // cannot run it should still list it once.
    if (outcome == UNSUPPORTED)
      for (entry in records) if (entry.outcome == UNSUPPORTED && entry.script == script) return;
    records.push({script: script, outcome: outcome, detail: detail == null ? '' : detail});
  }

  /** What was recorded since `beginSession`. */
  public static function sessionRecords():Array<LuaLoadRecord>
  {
    return records.copy();
  }

  /** Scripts found by a build that cannot run them. */
  public static function unsupportedScripts():Array<String>
  {
    return [for (entry in records) if (entry.outcome == UNSUPPORTED) entry.script];
  }

  /** Number of records with the given outcome. */
  public static function countOutcome(outcome:LuaLoadOutcome):Int
  {
    var count:Int = 0;
    for (entry in records) if (entry.outcome == outcome) count++;
    return count;
  }

  static function isFailure(outcome:LuaLoadOutcome):Bool
  {
    return outcome != LOADED && outcome != MISNAMED && outcome != OVERRIDDEN && outcome != UNSUPPORTED;
  }

  /** Whether any script that the engine tried to load did not load. */
  public static function hasFailures():Bool
  {
    for (entry in records) if (isFailure(entry.outcome)) return true;
    return false;
  }

  /**
   * The end-of-load report: one headline, then one line per script that did
   * not load. Empty when there is nothing to say (no Lua scripts at all).
   * Scripts replaced by a same-named one are by design, so they are only
   * listed with `includeOverridden`.
   */
  public static function summaryLines(includeOverridden:Bool = true):Array<String>
  {
    var lines:Array<String> = [];
    if (records.length == 0) return lines;

    var loaded:Int = countOutcome(LOADED);
    var misnamed:Int = countOutcome(MISNAMED);
    var overridden:Int = countOutcome(OVERRIDDEN);
    var unsupported:Int = countOutcome(UNSUPPORTED);
    var failed:Int = records.length - loaded - misnamed - overridden - unsupported;

    var headline:String = 'Lua scripts' + (sessionLabel.length > 0 ? ' for $sessionLabel' : '') + ': $loaded loaded';
    if (failed > 0) headline += ', $failed FAILED';
    if (misnamed > 0) headline += ', $misnamed skipped (file name is not *.lua)';
    if (overridden > 0) headline += ', $overridden replaced by a same-named script';
    if (unsupported > 0) headline += ', $unsupported not run (no Lua support in this build)';
    lines.push(headline);

    for (entry in records)
    {
      if (isFailure(entry.outcome)) lines.push('  FAILED  ${entry.script} - ${entry.outcome}: ${entry.detail}');
      else if (entry.outcome == MISNAMED || (entry.outcome == OVERRIDDEN && includeOverridden))
        lines.push('  SKIPPED ${entry.script} - ${entry.detail}');
    }
    return lines;
  }

  /**
   * Print the end-of-load report.
   *
   * Console: always when a script failed, was skipped for its name, or
   * cannot run in this build; otherwise only in verbose mode. On screen: a
   * build without Lua that found scripts says so (nothing else would ever
   * tell the player) once per run, so it does not nag on every song; in
   * verbose mode every time, plus the headline.
   */
  public static function reportSummary():Void
  {
    var unsupported:Array<String> = unsupportedScripts();
    if (unsupported.length > 0)
    {
      var lines:Array<String> = noLuaSupportLines(unsupported);
      for (line in lines) emit('ERROR: ' + line);
      if (verbose || !unsupportedShownOnScreen)
      {
        unsupportedShownOnScreen = true;
        show(lines.slice(0, NO_LUA_SCREEN_LINES).join('\n'), ERROR);
      }
    }

    var summary:Array<String> = summaryLines(verbose);
    if (summary.length == 0)
    {
      log('no Lua script was found for $sessionLabel');
      return;
    }

    var problems:Bool = hasFailures() || countOutcome(MISNAMED) > 0;
    if (verbose || problems) for (line in summary) emit(line);
    if (verbose) show(summary[0], problems ? ERROR : INFO);
  }

  // ---------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------

  static function compareStrings(a:String, b:String):Int
  {
    return a < b ? -1 : (a > b ? 1 : 0);
  }

  static function defaultFs():Null<LuaScanFs>
  {
    #if sys
    return {
      exists: sys.FileSystem.exists,
      isDirectory: sys.FileSystem.isDirectory,
      readDirectory: sys.FileSystem.readDirectory
    };
    #else
    return null;
    #end
  }
}
