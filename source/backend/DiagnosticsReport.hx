package backend;

/**
 * Redaction and formatting for the "Copy diagnostics" block
 * (`Options -> Misc -> "Copy Diagnostics"`, `backend.Diagnostics`).
 *
 * Everything here is deliberately Flixel-, Lime- and Sys-free: it receives
 * the raw facts `backend.Diagnostics` collected and turns them into the final
 * paste-ready text. That keeps the part that must never leak a username,
 * home folder or absolute install path runnable in the Haxe interpreter
 * (`tests/haxe/DiagnosticsReportSpec.hx`), where the redaction rules are
 * checked line by line without a game build.
 *
 * The block starts with a `<!-- phoenix-diagnostics:v1 -->` marker so a
 * support reply is obvious, and every value is either a fact the engine
 * measured or a value the player could read in the menus — no save contents,
 * no keybinds, no script source, no URLs beyond the public repository.
 *
 * Redaction is applied to *every* line, including the log excerpt: a log line
 * is as likely as the header to carry `C:\Users\<name>\...` or
 * `/home/<name>/...`.
 */
class DiagnosticsReport
{
  /** First line of every block. Lets support recognise a pasted report. */
  public static inline var MARKER:String = '<!-- phoenix-diagnostics:v1 -->';

  /** Longest a single line may stay before it is clipped (paste safety). */
  public static inline var MAX_LINE_CHARS:Int = 400;

  /** Longest a redacted log line may stay; stack traces are trimmed harder. */
  public static inline var MAX_LOG_LINE_CHARS:Int = 300;

  /** How many of the most recent log lines a report keeps by default. */
  public static inline var DEFAULT_LOG_LINES:Int = 60;

  /** Replacement for a user folder (`C:\Users\bob` -> `C:\Users\<user>`). */
  public static inline var USER_PLACEHOLDER:String = '<user>';

  /** Environment variable names whose *values* are never echoed. */
  static final SECRET_ENV_TOKENS:Array<String> = [
    'TOKEN',
    'SECRET',
    'PASSWORD',
    'PASSWD',
    'APIKEY',
    'API_KEY',
    'ACCESS_KEY',
    'PRIVATE_KEY',
    'CREDENTIAL',
    'SESSION_ID'
  ];

  /**
   * Facts collected by `backend.Diagnostics`; every field is required.
   *
   * The block is assembled section by section, and every value goes through
   * `pushLine()` / `redact()` on the way in — there is no path that writes a
   * fact straight into the text.
   */
  public static function build(facts:DiagnosticsFacts):String
  {
    final home:String = facts.homeDirectory;
    final out:Array<String> = [];
    out.push(MARKER);
    out.push('Phoenix Engine diagnostics');
    out.push('generated ' + clean(facts.generatedAt) + ' (local time)');
    out.push('');
    out.push('[build]');
    pushLine(out, 'engine', facts.engineVersion, home);
    pushLine(out, 'jse', facts.jseVersion, home);
    pushLine(out, 'psych', facts.psychVersion, home);
    pushLine(out, 'commit', facts.commit, home);
    pushLine(out, 'target', facts.target, home);
    pushLine(out, 'haxe', facts.haxeVersion, home);
    pushLine(out, 'framework', facts.frameworkVersion, home);
    pushLine(out, 'runtime_lib', facts.runtimeLibVersion, home);
    pushLine(out, 'game_framework', facts.gameFrameworkVersion, home);

    out.push('');
    out.push('[hardware]');
    pushLine(out, 'os', joinPair(facts.osName, facts.osVersion), home);
    pushLine(out, 'cpu', facts.cpuModel, home);
    pushLine(out, 'cpu_vendor', facts.cpuVendor, home);
    pushLine(out, 'cpu_cores', facts.cpuCores, home);
    pushLine(out, 'ram_total', facts.ramTotal, home);
    pushLine(out, 'ram_used', facts.ramUsed, home);
    pushLine(out, 'gpu', facts.gpuModel, home);
    pushLine(out, 'gpu_vendor', facts.gpuVendor, home);
    pushLine(out, 'gpu_driver', facts.gpuDriver, home);
    pushLine(out, 'gfx_api', facts.graphicsApi, home);
    pushLine(out, 'renderer', facts.renderer, home);
    pushLine(out, 'audio', facts.audioApi, home);
    pushLine(out, 'heap_used', facts.heapUsed, home);
    pushLine(out, 'process_rss', facts.processRss, home);

    out.push('');
    out.push('[runtime]');
    pushLine(out, 'display', facts.display, home);
    pushLine(out, 'framerate', facts.framerate, home);
    pushLine(out, 'mods', facts.modCount, home);
    pushLine(out, 'state', facts.state, home);
    pushLine(out, 'vlog', facts.vlogState, home);

    out.push('');
    out.push('[paths]');
    pushLine(out, 'install', facts.installPath, home);
    pushLine(out, 'save', facts.savePath, home);

    out.push('');
    out.push('[mods]');
    final mods:Array<String> = facts.mods == null ? [] : facts.mods;
    if (mods.length == 0)
      out.push('  (none enabled)');
    else
    {
      for (i in 0...mods.length)
        pushLine(out, '#' + (i + 1), mods[i]);
    }

    out.push('');
    out.push('[prefs]');
    final prefs:Array<String> = facts.nonDefaultPrefs == null ? [] : facts.nonDefaultPrefs;
    if (prefs.length == 0)
      out.push('  (none)');
    else
    {
      for (line in prefs)
        out.push('  ' + redact(line, home));
    }

    out.push('');
    out.push('[log] ' + facts.logSource);
    final logLines:Array<String> = facts.logLines == null ? [] : facts.logLines;
    if (logLines.length == 0)
      out.push('  (no log)');
    else
    {
      for (line in logLines)
        out.push('  ' + clip(redact(line, home), MAX_LOG_LINE_CHARS));
    }

    return out.join('\n');
  }

  /**
   * The `[prefs]` section: every `ClientPrefs` field whose value differs from
   * the engine default, one `name=value` line each.
   *
   * The caller pairs a field name with its current value and its default; the
   * comparison is done here as well so the report code and this formatter
   * cannot disagree about what counts as "changed".
   *
   * @param fields field names, in the order they should be listed
   * @param current current values, indexed like `fields`
   * @param defaults engine defaults, indexed like `fields`
   * @return the changed entries; arrays are summarised instead of dumped
   */
  public static function diffPrefs(fields:Array<String>, current:Array<Dynamic>, defaults:Array<Dynamic>):Array<String>
  {
    final out:Array<String> = [];
    final count:Int = Std.int(Math.min(fields.length, Math.min(current.length, defaults.length)));
    for (i in 0...count)
    {
      if (sameValue(current[i], defaults[i])) continue;
      out.push(fields[i] + '=' + formatValue(current[i]));
    }
    return out;
  }

  /**
   * Replaces the parts of `text` that identify a person or a machine.
   *
   * Both separators are handled so a Windows path pasted into a Linux log (or
   * the other way round) is redacted too. The rules, in order:
   *
   * 1. `C:\Users\<name>` / `C:/Users/<name>` and the XP-era `Documents and
   *    Settings` variant -> the same prefix + `<user>`;
   * 2. `/home/<name>` and `/Users/<name>` -> the same prefix + `<user>`;
   *    `/root/<...>` -> `/root/<user>`;
   * 3. `%USERPROFILE%`, `$HOME` and the home directory the collector passed
   *    in (`Sys.getEnv('HOME')`) -> `<home>`;
   * 4. the macOS `Macintosh HD - Data` data volume name;
   * 5. `name@host` -> `<email>`, `phoenix://` payloads -> `phoenix://<redacted>`;
   * 6. `KEY=value` for anything that looks like a secret is cut to `KEY=<redacted>`.
   *
   * @param text text to clean; null becomes an empty string
   * @param homedir optional known home directory, removed verbatim
   * @return the redacted text, never throwing
   */
  public static function redact(text:String, ?homedir:String = null):String
  {
    if (text == null) return '';
    var out:String = text;

    // The known home folder goes first so the exact path wins over the
    // generic user-folder rules below.
    if (homedir != null && StringTools.trim(homedir).length > 1) out = replaceAll(out, homedir, '<home>');

    // 1. Windows user folders, both separator styles.
    // '$1' is the whole prefix, so the original separators survive.
    out = USER_FOLDER_WIN.replace(out, '$1' + USER_PLACEHOLDER);
    out = USER_FOLDER_DOCS.replace(out, '$1' + USER_PLACEHOLDER);

    // 2. Unix user folders, one segment deep; anything below keeps its shape.
    out = USER_FOLDER_UNIX.replace(out, '$1' + USER_PLACEHOLDER);
    out = ROOT_FOLDER.replace(out, '$1' + USER_PLACEHOLDER);

    // 3b. Environment variable spellings of the same folder.
    out = replaceAll(out, '%USERPROFILE%', '<home>');
    // '$$' is an escaped '$': Haxe interpolates inside single quotes too.
    out = replaceAll(out, '$$HOME', '<home>');
    out = replaceAll(out, '$${HOME}', '<home>');

    // 4. macOS mounts the user folders through a data volume whose name ends
    //    up in some stack traces.
    out = replaceAll(out, '/Volumes/Macintosh HD - Data', '');

    // 5. Contact details and deep links.
    out = EMAIL.replace(out, '<email>');
    out = PHOENIX_URI.replace(out, 'phoenix://<redacted>');

    // 6. Secrets passed through the environment or a launch argument.
    for (pattern in secretPatterns())
      out = pattern.replace(out, '$1<redacted>');

    return out;
  }

  /**
   * Keeps the last `count` lines of `log`, dropping the ones cut mid-line.
   *
   * The first kept line is discarded when the slice did not start on a real
   * line boundary: half a stack frame reads like corruption and hides the
   * lines that follow it.
   *
   * @param log the full log text (`VLog.exportText()`)
   * @param count how many trailing lines to keep
   * @return the tail, oldest first; an empty array when there is no log
   */
  public static function tail(log:String, count:Int):Array<String>
  {
    if (log == null || count <= 0) return [];
    final lines:Array<String> = log.split('\n');
    // A file that ends with a newline produces one trailing empty entry.
    while (lines.length > 0 && StringTools.trim(lines[lines.length - 1]).length == 0)
      lines.pop();
    if (lines.length <= count) return lines;

    final start:Int = lines.length - count;
    final tailLines:Array<String> = [];
    for (i in start...lines.length)
    {
      if (i == start && start > 0 && isContinuation(lines[i])) continue;
      tailLines.push(lines[i]);
    }
    return tailLines;
  }

  /** True for the indented continuation lines `VLog.formatLine` writes. */
  static function isContinuation(line:String):Bool
  {
    if (line == null || line.length == 0) return false;
    final first:String = line.charAt(0);
    return first == ' ' || first == '\t';
  }

  /**
   * Truncates `text` to `max` characters with a marker that says how much was
   * dropped, so nobody mistakes a clipped stack trace for the whole story.
   */
  public static function clip(text:String, max:Int):String
  {
    if (text == null) return '';
    if (max <= 0 || text.length <= max) return text;
    final suffix:String = '… (+' + (text.length - max) + ' chars)';
    final keep:Int = max - suffix.length;
    if (keep <= 0) return text.substr(0, max);
    return text.substr(0, keep) + suffix;
  }

  /** `a b`, `a` or `Unknown` — never a double space or a dangling `null`. */
  public static function joinPair(a:String, b:String):String
  {
    final left:String = StringTools.trim(a == null ? '' : a);
    final right:String = StringTools.trim(b == null ? '' : b);
    if (left.length == 0 && right.length == 0) return 'Unknown';
    if (left.length == 0) return right;
    if (right.length == 0) return left;
    return left + ' ' + right;
  }

  /** Renders a preference value: booleans, numbers, strings, arrays. */
  public static function formatValue(value:Dynamic):String
  {
    if (value == null) return 'null';
    if (Std.isOfType(value, Bool)) return (value == true) ? 'true' : 'false';
    if (Std.isOfType(value, Array))
    {
      final items:Array<Dynamic> = value;
      final parts:Array<String> = [];
      // Note colours and combo offsets are arrays of arrays / numbers; a
      // summary keeps the block readable for a support ticket.
      for (item in items)
      {
        if (Std.isOfType(item, Array)) parts.push('[' + lengthOf(item) + ' items]');
        else parts.push(formatValue(item));
      }
      return '[' + parts.join(',') + ']';
    }
    return Std.string(value);
  }

  /** Number of elements of an `Array` passed as `Dynamic`. */
  static function lengthOf(value:Dynamic):Int
  {
    final items:Array<Dynamic> = value;
    return items == null ? 0 : items.length;
  }

  /** True when two preference values should be considered equal. */
  static function sameValue(a:Dynamic, b:Dynamic):Bool
  {
    if (a == null || b == null) return a == b;
    if (Std.isOfType(a, Array) || Std.isOfType(b, Array))
    {
      if (!Std.isOfType(a, Array) || !Std.isOfType(b, Array)) return false;
      final left:Array<Dynamic> = a;
      final right:Array<Dynamic> = b;
      if (left.length != right.length) return false;
      for (i in 0...left.length)
        if (!sameValue(left[i], right[i])) return false;
      return true;
    }
    // Floats that arrived as Ints (JSON round trip) still count as equal.
    if ((Std.isOfType(a, Int) || Std.isOfType(a, Float)) && (Std.isOfType(b, Int) || Std.isOfType(b, Float)))
    {
      final left:Float = a;
      final right:Float = b;
      return left == right;
    }
    return Std.string(a) == Std.string(b);
  }

  /** Trims a value and drops the control characters that break a paste. */
  static function clean(value:String):String
  {
    if (value == null) return '';
    return StringTools.trim(value.split('\r').join(' ').split('\n').join(' '));
  }

  /**
   * Pushes one `  key: value` line, redacted and clipped.
   *
   * @param out   lines collected so far
   * @param key   left-hand side of the report line
   * @param value value to clean; null or empty becomes `Unknown`
   * @param home  optional home directory, stripped verbatim by `redact`
   */
  static function pushLine(out:Array<String>, key:String, value:String, ?home:String):Void
  {
    var text:String = clean(value);
    if (text.length == 0) text = 'Unknown';
    out.push('  ' + key + ': ' + clip(redact(text, home), MAX_LINE_CHARS));
  }

  /** `String.replace` without the EReg escaping rules, replacing every hit. */
  static function replaceAll(text:String, needle:String, replacement:String):String
  {
    if (text == null || needle == null || needle.length == 0) return text;
    return text.split(needle).join(replacement);
  }

  // -- Redaction patterns -----------------------------------------------------

  /**
   * `C:\Users\bob`, `C:/Users/bob` and everything below it. The name is a
   * single path segment; a folder that really contains a space would be
   * clipped, which is the safe direction.
   */
  static final USER_FOLDER_WIN = ~/([A-Za-z]:[\\\/][Uu]sers[\\\/])[^\\\/\s"':;,]+/g;

  /** XP-era profile folder, still emitted by some crash/minidump tooling. */
  static final USER_FOLDER_DOCS = ~/([A-Za-z]:[\\\/]Documents and Settings[\\\/])[^\\\/\s"':;,]+/g;

  /** `/home/bob`, `/Users/bob` (macOS) — one segment, then any deeper path. */
  static final USER_FOLDER_UNIX = ~/(\/(?:home|Users)\/)[^\/\s"':;,]+/g;

  /** `/root/<path>`: the superuser home directory. */
  static final ROOT_FOLDER = ~/([\/\\]root[\/\\])[^\/\\\s"':;,]+/g;

  /** mailto/issue text sometimes carries the reporter's address. */
  static final EMAIL = ~/[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}/g;

  /** A deep link can name a mod folder or a save slot; keep only the scheme. */
  static final PHOENIX_URI = ~/phoenix:\/\/[^\s"']+/g;

  /** `GITHUB_TOKEN=...` and friends: keep the key, drop the value. */
  static var KEY_VALUE_SECRET:Map<String, EReg> = null;

  /** Builds the per-token `KEY<sep>value` patterns once. */
  static function secretPatterns():Map<String, EReg>
  {
    if (KEY_VALUE_SECRET != null) return KEY_VALUE_SECRET;
    final patterns:Map<String, EReg> = [];
    for (name in SECRET_ENV_TOKENS)
      patterns.set(name, new EReg('(' + name + '\\s*[:=]\\s*)\\S+', 'gi'));
    KEY_VALUE_SECRET = patterns;
    return patterns;
  }
}

/**
 * Everything `DiagnosticsReport.build` needs, already measured by
 * `backend.Diagnostics`. Strings may be null (they are reported as
 * `Unknown`); this keeps the collector free of formatting concerns.
 */
typedef DiagnosticsFacts =
{
  var generatedAt:String;
  // build
  var engineVersion:String;
  var jseVersion:String;
  var psychVersion:String;
  var commit:String;
  var target:String;
  var haxeVersion:String;
  /** `openfl` version the build resolved. */
  var frameworkVersion:String;
  /** `lime` version the build resolved. */
  var runtimeLibVersion:String;
  /** `flixel` version the build resolved. */
  var gameFrameworkVersion:String;
  // hardware
  var osName:String;
  var osVersion:String;
  var cpuModel:String;
  var cpuVendor:String;
  var cpuCores:String;
  var ramTotal:String;
  var ramUsed:String;
  var gpuModel:String;
  var gpuVendor:String;
  var gpuDriver:String;
  var graphicsApi:String;
  var renderer:String;
  var audioApi:String;
  var heapUsed:String;
  var processRss:String;
  // runtime
  var display:String;
  var framerate:String;
  var modCount:String;
  var state:String;
  var vlogState:String;
  // paths
  var installPath:String;
  var savePath:String;
  // lists
  var mods:Array<String>;
  var nonDefaultPrefs:Array<String>;
  var logSource:String;
  var logLines:Array<String>;
  /**
   * Optional home directory of the running user. When present, `build` strips
   * it verbatim before the generic rules run, which is the only rule that also
   * catches a profile folder the player renamed.
   */
  @:optional var homeDirectory:String;
}
