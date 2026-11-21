package backend;

#if CLI_OPTIONS_ALLOWED
import docopt.Docopt;
// DocoptOptions shares the docopt.Docopt module file, so it needs the full path.
import docopt.Docopt.DocoptOptions;
import docopt.DocoptExit;
import docopt.ParsedOptions;
#end

/**
 * Runtime launch options: what the player asked for on the command line.
 *
 * The argument vector is parsed once, as early as `Main.main()` runs, by
 * [docopt-ng](https://lib.haxe.org/p/docopt-ng/) against the {@link USAGE}
 * docstring. The help text, the accepted spellings and the grammar the parser
 * enforces are therefore the same string and cannot drift apart.
 *
 * Everything here is a **session** override: nothing is written to the save
 * file, and `Options` keeps showing the player's saved preferences.
 *
 * Rules this class follows:
 *
 * - **A game must boot.** {@link parse} never throws. A vector docopt rejects
 *   (unknown flag, unusable value) is reported in {@link LaunchOptions.error}
 *   and the engine starts with the saved preferences, so a stale desktop
 *   shortcut or a launcher that appends its own arguments cannot stop it.
 *   `phoenix://` links are still honored on that path: a protocol launch looks
 *   exactly like "the game ignored my argument" otherwise.
 * - **Renderer-free.** No Flixel, OpenFL or Lime type appears here, which is
 *   what lets `tests/haxe/run-command-line.sh` check the whole contract in the
 *   Haxe interpreter, and what keeps `backend.WindowMode` spelled as plain
 *   strings ({@link MODE_WINDOWED} and friends) instead of being imported.
 * - **Legacy spellings keep working.** `-troll` (`Main.superDangerMode`) and
 *   `-profile` / `--frame-profiler` (`debug.FrameProfiler`) were read by hand
 *   before docopt existed; {@link normalizeLegacy} rewrites them first.
 *
 * Player-facing reference: `docs/CLI.md`. The `phoenix://` routes accepted as
 * positional arguments are documented in `URI.MD`.
 */
class CommandLine
{
  /** Executable name the usage text is written for (`EXECUTABLE_NAME` in `project.hxp`). */
  public static inline var PROGRAM_NAME:String = 'FNF-Phoenix-Engine';

  /** Scheme a positional argument must start with to be a deeplink (`URI.MD`). */
  public static inline var URI_SCHEME:String = 'phoenix://';

  /** Lower bound for `--fps`, mirroring `backend.FramerateMath.MIN_FPS`. */
  public static inline var MIN_FPS:Int = 1;

  /** Upper bound for `--fps`, mirroring `backend.FramerateMath.UNCAPPED_CAP`. */
  public static inline var MAX_FPS:Int = 10000;

  /** Window mode names, spelled exactly like the `backend.WindowMode` constants. */
  public static inline var MODE_WINDOWED:String = 'Windowed';

  /** @see {@link MODE_WINDOWED} */
  public static inline var MODE_BORDERLESS:String = 'Borderless';

  /** @see {@link MODE_WINDOWED} */
  public static inline var MODE_FULLSCREEN:String = 'Fullscreen';

  /** Longest `--song` / `--mod` segment; `PhoenixURI` bounds its whole input to 256. */
  static inline var MAX_SEGMENT:Int = 64;

  /**
   * docopt docstring: the `--help` output and the grammar the parser enforces.
   *
   * Written as a joined list instead of one multi-line literal so the option
   * table keeps the file's indentation and the two-space gap docopt needs
   * between an option and its description stays visible.
   *
   * One usage line with the `[options]` shortcut on purpose: docopt-ng turns a
   * spelled-out `(-h | --help)` alternative into a sequence that needs *both*
   * tokens, so `-h` alone would be rejected. Through the shortcut every
   * documented option — help and version included — is accepted in any
   * combination, and an empty vector (an icon launch) matches too.
   */
  public static final USAGE:String = [
    "Friday Night Funkin' - Phoenix Engine.",
    '',
    'Usage:',
    '  $PROGRAM_NAME [options] [URI...]',
    '',
    'Options:',
    '  -h --help          Show this text and exit.',
    '  --version          Show the engine version and exit.',
    '  -w --windowed      Start in a window, ignoring the saved window mode.',
    '  -f --fullscreen    Start in exclusive fullscreen, ignoring the saved mode.',
    '  -b --borderless    Start borderless fullscreen, ignoring the saved mode.',
    '  --fps=<n>          Gameplay framerate for this session ($MIN_FPS-$MAX_FPS).',
    '  --freeplay         Boot straight into FreeplayState, like -DFREEPLAY.',
    '  --menu             Boot straight into MainMenuState, like -DMENU.',
    '  --song=<name>      Open the phoenix song route for that song after boot.',
    '  --mod=<id>         Open the phoenix mod route for that mod after boot.',
    '  --profile          Turn the frame profiler on and export its log on exit.',
    '  --vlog             Write the verbose log (vlog/log.txt) for this session.',
    '  --safe-mode        Boot into the recovery screen, like a crash loop would.',
    '  --troll            Allow selfDestruction (legacy spelling: -troll).',
    '  --no-deeplinks     Ignore every phoenix link on the command line.',
    '',
    'Arguments:',
    '  URI  phoenix links to open after boot, exactly like the ones Windows hands',
    '       to the executable when it launches the registered protocol (URI.MD).',
    ''
  ].join('\n');

  /**
   * Spellings that predate docopt. One dash in front of a whole word is a
   * *cluster* of short options to docopt (`-troll` would be `-t -r -o -l -l`),
   * so these are rewritten to their long form before parsing.
   */
  static final LEGACY_FLAGS:Map<String, String> = [
    '-troll' => '--troll',
    '-profile' => '--profile',
    '--frame-profiler' => '--profile'
  ];

  /** Characters a `phoenix://` path segment may use (`PhoenixURI.parseEx`). */
  static final SEGMENT_PATTERN:EReg = ~/^[a-z0-9_-]+$/i;

  /** Whole integers only, so `--fps=60.5` is reported instead of truncated. */
  static final INTEGER_PATTERN:EReg = ~/^-?[0-9]+$/;

  /** Result of the last {@link load}; `null` until something asks for it. */
  static var parsed:Null<LaunchOptions> = null;

  /**
   * The gameplay rate a `--fps` override replaced in `backend.ClientPrefs`, so
   * `ClientPrefs.saveSettings()` can write the player's own number back instead
   * of baking the session value in as a choice they never made. `null` until
   * `ClientPrefs.loadPrefs()` installs the override — the same protection
   * `backend.LowMemory.beginSave()` gives the preferences a memory profile
   * forces.
   */
  public static var savedFramerate:Null<Int> = null;

  /** Long option names found in {@link USAGE}, collected on first use. */
  static var longOptionNames:Null<Array<String>> = null;

  /**
   * The options of this process. Parsed on first access, so a caller can never
   * observe a half-initialized record no matter which static runs first.
   */
  public static var options(get, never):LaunchOptions;

  /**
   * @return The remembered vector, parsing {@link load} it when needed.
   */
  static function get_options():LaunchOptions
  {
    if (parsed == null) load();
    return parsed;
  }

  /**
   * Parse this process's arguments once and remember the result. Called from
   * `Main.main()` before the window exists; every later reader goes through
   * {@link options}.
   *
   * @param args Argument vector. `null` reads `Sys.args()` on system targets
   *   and yields an empty vector everywhere else (web, Flash and AIR have no
   *   command line to read).
   * @return The options for the rest of the session.
   */
  public static function load(?args:Null<Array<String>>):LaunchOptions
  {
    var vector:Array<String> = args;
    if (vector == null)
    {
      vector = [];
      #if sys
      try
      {
        vector = Sys.args();
      }
      catch (problem:Dynamic)
      {
        vector = [];
      }
      #end
    }
    parsed = parse(vector);
    return parsed;
  }

  /** Forget the parsed vector and the session state built from it. Test hook. */
  public static function reset():Void
  {
    parsed = null;
    savedFramerate = null;
  }

  /**
   * Parse an argument vector. Pure: it reads nothing but `args`, so the spec
   * can hand it any vector without touching the process it runs in.
   *
   * @param args Raw arguments, e.g. `Sys.args()`. The array is copied, never
   *   mutated — docopt consumes the vector it is given.
   * @return The parsed record. Never throws; a rejected vector comes back with
   *   {@link LaunchOptions.error} set and every option at its default.
   */
  public static function parse(args:Null<Array<String>>):LaunchOptions
  {
    final raw:Array<String> = (args == null) ? [] : args.copy();
    final normalized:Array<String> = normalizeLegacy(raw);
    #if CLI_OPTIONS_ALLOWED
    try
    {
      // Help and version are answered by `Main` from the parsed record, not by
      // docopt throwing: the exit code and the output stream stay ours.
      final settings:DocoptOptions = {defaultHelp: false};
      return fromParsed(Docopt.parse(USAGE, normalized.copy(), settings), raw);
    }
    catch (exit:DocoptExit)
    {
      return rejected(raw, normalized, firstLine(exit.message));
    }
    catch (problem:Dynamic)
    {
      return rejected(raw, normalized, firstLine(Std.string(problem)));
    }
    #else
    return rejected(raw, normalized, 'launch options are not compiled into this build');
    #end
  }

  /**
   * Rewrite the spellings that predate docopt.
   *
   * @param args Raw arguments.
   * @return A new vector; the input is left untouched.
   */
  public static function normalizeLegacy(args:Array<String>):Array<String>
  {
    final normalized:Array<String> = [];
    if (args == null) return normalized;
    for (arg in args)
    {
      if (arg == null) continue;
      final legacy:Null<String> = LEGACY_FLAGS.get(arg);
      if (legacy != null)
      {
        normalized.push(legacy);
        continue;
      }
      final expanded:Null<String> = expandSingleDash(arg);
      normalized.push(expanded != null ? expanded : arg);
    }
    return normalized;
  }

  /**
   * `phoenix://` links this launch should open, in the order `DeepLinks`
   * receives them (it keeps the last one, so `--song` wins over a link).
   *
   * @param options Record to read; `null` uses this process's options.
   * @return The links, or an empty array when `--no-deeplinks` was given.
   */
  public static function deeplinks(?options:LaunchOptions):Array<String>
  {
    final record:LaunchOptions = (options != null) ? options : CommandLine.options;
    return record.noDeeplinks ? [] : record.uris;
  }

  /**
   * Window mode this session asks for, or `''` to keep the saved preference.
   *
   * Conflicting flags resolve in a fixed order — fullscreen, borderless,
   * windowed — the same way `backend.LaunchState` resolves `-DFREEPLAY`
   * against `-DMENU`: the outcome must not depend on argument order.
   *
   * @param options Record to read; `null` uses this process's options.
   * @return One of {@link MODE_WINDOWED}, {@link MODE_BORDERLESS},
   *   {@link MODE_FULLSCREEN}, or `''`.
   */
  public static function windowModeOverride(?options:LaunchOptions):String
  {
    final record:LaunchOptions = (options != null) ? options : CommandLine.options;
    if (record.fullscreen) return MODE_FULLSCREEN;
    if (record.borderless) return MODE_BORDERLESS;
    if (record.windowed) return MODE_WINDOWED;
    return '';
  }

  /**
   * Gameplay framerate this session asks for.
   *
   * @param options Record to read; `null` uses this process's options.
   * @return The clamped `--fps` value, or `null` when the saved preference wins.
   */
  public static function framerateOverride(?options:LaunchOptions):Null<Int>
  {
    final record:LaunchOptions = (options != null) ? options : CommandLine.options;
    return record.fps;
  }

  /**
   * Framerate to boot with: the `--fps` override, or the caller's default.
   *
   * @param fallback Rate used when `--fps` was not given (or was unusable).
   * @param options Record to read; `null` uses this process's options.
   * @return The rate for this session.
   */
  public static function framerate(fallback:Int, ?options:LaunchOptions):Int
  {
    final requested:Null<Int> = framerateOverride(options);
    return (requested != null) ? requested : fallback;
  }

  /** `--freeplay` as the override `backend.LaunchState.resolve` accepts. */
  public static function freeplayOverride(?options:LaunchOptions):Null<Bool>
  {
    final record:LaunchOptions = (options != null) ? options : CommandLine.options;
    return record.freeplay ? true : null;
  }

  /**
   * `--menu` as the override `backend.LaunchState.resolve` accepts. Given both
   * flags, `LaunchState.resolve` lets freeplay win — its documented conflict
   * rule, unchanged by the command line.
   */
  public static function menuOverride(?options:LaunchOptions):Null<Bool>
  {
    final record:LaunchOptions = (options != null) ? options : CommandLine.options;
    return record.menu ? true : null;
  }

  /** The `--help` output: the very docstring docopt parsed. */
  public static function helpText():String
  {
    return StringTools.trim(USAGE);
  }

  /**
   * The `--version` output.
   *
   * @param version Engine version (`backend.PhoenixVersion.current`).
   * @return A single line, e.g. `FNF-Phoenix-Engine 0.0.1`.
   */
  public static function versionText(version:String):String
  {
    return '$PROGRAM_NAME ${version == null ? 'unknown' : version}';
  }

  /**
   * One-line summary for the vlog: which options this session requested.
   *
   * @param options Record to read; `null` uses this process's options.
   * @return The requested options and links, or `none` for a plain launch.
   */
  public static function describe(?options:LaunchOptions):String
  {
    final record:LaunchOptions = (options != null) ? options : CommandLine.options;
    final parts:Array<String> = [];
    if (record.windowed) parts.push('--windowed');
    if (record.fullscreen) parts.push('--fullscreen');
    if (record.borderless) parts.push('--borderless');
    if (record.fps != null) parts.push('--fps=${record.fps}');
    if (record.freeplay) parts.push('--freeplay');
    if (record.menu) parts.push('--menu');
    if (record.profile) parts.push('--profile');
    if (record.vlog) parts.push('--vlog');
    if (record.safeMode) parts.push('--safe-mode');
    if (record.troll) parts.push('--troll');
    if (record.noDeeplinks) parts.push('--no-deeplinks');
    for (uri in record.uris) parts.push(uri);
    if (record.error != null) parts.push('ignored: ${record.error}');
    return parts.length == 0 ? 'none' : parts.join(' ');
  }

  /** A record with nothing requested: an icon launch, or a rejected vector. */
  public static function defaults():LaunchOptions
  {
    return {
      help: false,
      version: false,
      windowed: false,
      fullscreen: false,
      borderless: false,
      fps: null,
      freeplay: false,
      menu: false,
      song: null,
      mod: null,
      profile: false,
      vlog: false,
      safeMode: false,
      troll: false,
      noDeeplinks: false,
      uris: [],
      raw: [],
      error: null
    };
  }

  #if CLI_OPTIONS_ALLOWED
  /**
   * Map docopt's dynamic result onto the typed {@link LaunchOptions} record.
   *
   * @param parsed docopt's result; keys are the docstring spellings.
   * @param raw Arguments as they came in, kept for the vlog and diagnostics.
   * @return The record; values docopt could not use are reported in `error`.
   */
  static function fromParsed(parsed:ParsedOptions, raw:Array<String>):LaunchOptions
  {
    final options:LaunchOptions = defaults();
    final notes:Array<String> = [];
    options.raw = raw;

    options.help = flagOf(parsed.help);
    options.version = flagOf(parsed.version);
    options.windowed = flagOf(parsed.windowed);
    options.fullscreen = flagOf(parsed.fullscreen);
    options.borderless = flagOf(parsed.borderless);
    options.freeplay = flagOf(parsed.freeplay);
    options.menu = flagOf(parsed.menu);
    options.profile = flagOf(parsed.profile);
    options.vlog = flagOf(parsed.vlog);
    options.safeMode = flagOf(parsed.safe_mode);
    options.troll = flagOf(parsed.troll);
    options.noDeeplinks = flagOf(parsed.no_deeplinks);

    final fpsText:Null<String> = textOf(parsed.fps);
    if (fpsText != null)
    {
      if (INTEGER_PATTERN.match(fpsText)) options.fps = clampFps(Std.parseInt(fpsText));
      else notes.push('--fps="$fpsText" is not a whole number');
    }

    final song:Null<String> = textOf(parsed.song);
    if (song != null)
    {
      if (validSegment(song)) options.song = song;
      else notes.push('--song="$song" is not a phoenix path segment');
    }

    final mod:Null<String> = textOf(parsed.mod);
    if (mod != null)
    {
      if (validSegment(mod)) options.mod = mod;
      else notes.push('--mod="$mod" is not a phoenix path segment');
    }

    // Positional arguments: only phoenix:// links are actionable. Anything
    // else (a stray path, a launcher's own argument) is reported and dropped
    // instead of being handed to DeepLinks; `--` is docopt's "end of options"
    // marker and is dropped silently.
    final links:Array<String> = [];
    for (positional in listOf(parsed.URI))
    {
      if (positional == '--') continue;
      if (StringTools.startsWith(positional.toLowerCase(), URI_SCHEME)) links.push(positional);
      else notes.push('"$positional" is not a recognized argument');
    }
    // Positional links first, then the routes built from --song/--mod, so an
    // explicit option wins the "last link received" rule DeepLinks applies.
    options.uris = links.concat(syntheticUris(options));
    options.error = notes.length == 0 ? null : notes.join('; ');
    return options;
  }
  #end

  /**
   * Boot defaults plus the links found in a vector the parser could not use.
   *
   * @param raw Arguments as they came in.
   * @param normalized Arguments after {@link normalizeLegacy}.
   * @param message Why the vector was rejected, one line.
   * @return A record that still delivers a protocol launch.
   */
  static function rejected(raw:Array<String>, normalized:Array<String>, message:String):LaunchOptions
  {
    final options:LaunchOptions = defaults();
    options.raw = raw;
    options.error = message;
    options.uris = scanUris(normalized);
    return options;
  }

  /** Every `phoenix://` argument in a vector, in the order given. */
  static function scanUris(args:Array<String>):Array<String>
  {
    final uris:Array<String> = [];
    for (arg in args)
    {
      // StringTools is a global `using` in the game build (source/import.hx),
      // but not in the isolated spec, so this call stays explicit.
      if (arg != null && StringTools.startsWith(arg.toLowerCase(), URI_SCHEME)) uris.push(arg);
    }
    return uris;
  }

  /** The `phoenix://` routes implied by `--song` / `--mod` (`URI.MD` v2 routes). */
  static function syntheticUris(options:LaunchOptions):Array<String>
  {
    final uris:Array<String> = [];
    if (options.mod != null)
      uris.push(options.song != null ? '${URI_SCHEME}mod/${options.mod}/song/${options.song}' : '${URI_SCHEME}mod/${options.mod}');
    else if (options.song != null) uris.push('${URI_SCHEME}song/${options.song}');
    return uris;
  }

  /**
   * `-fullscreen` → `--fullscreen`: one dash in front of a whole word would be
   * read as a cluster of short options, which is never what a player means.
   *
   * @param arg A single argument.
   * @return The long spelling, or `null` when `arg` is not a known option.
   */
  static function expandSingleDash(arg:String):Null<String>
  {
    if (arg.length < 4 || arg.charAt(0) != '-' || arg.charAt(1) == '-') return null;
    final equals:Int = arg.indexOf('=');
    final name:String = (equals >= 0) ? arg.substring(1, equals) : arg.substring(1);
    return knownLongOption(name) ? '--' + arg.substring(1) : null;
  }

  /** Whether `--name` is documented in {@link USAGE}. */
  static function knownLongOption(name:String):Bool
  {
    if (longOptionNames == null) longOptionNames = collectLongOptions();
    return longOptionNames.indexOf(name) >= 0;
  }

  /** Read every `--long` name out of {@link USAGE}, so the two cannot drift. */
  static function collectLongOptions():Array<String>
  {
    final names:Array<String> = [];
    final pattern:EReg = ~/(^|\s)--([a-z0-9][a-z0-9-]*)/;
    var rest:String = USAGE;
    while (pattern.match(rest))
    {
      final name:String = pattern.matched(2);
      if (names.indexOf(name) < 0) names.push(name);
      rest = pattern.matchedRight();
    }
    return names;
  }

  /** docopt reports a flag as `true`; anything else means "not requested". */
  static function flagOf(value:Dynamic):Bool
  {
    return value == true;
  }

  /** A trimmed non-empty string, or `null` when the option was not given. */
  static function textOf(value:Dynamic):Null<String>
  {
    if (value == null || value == false || value == true) return null;
    final text:String = StringTools.trim(Std.string(value));
    return text.length == 0 ? null : text;
  }

  /** Positional values: docopt gives an array for `[URI...]`, `null` when empty. */
  static function listOf(value:Dynamic):Array<String>
  {
    final values:Array<String> = [];
    if (value == null) return values;
    if (Std.isOfType(value, Array))
    {
      for (item in (cast value : Array<Dynamic>))
      {
        final text:Null<String> = textOf(item);
        if (text != null) values.push(text);
      }
      return values;
    }
    final single:Null<String> = textOf(value);
    return single == null ? values : [single];
  }

  /** Whether a value can be a `phoenix://` path segment (`PhoenixURI.parseEx`). */
  static function validSegment(value:String):Bool
  {
    return value.length <= MAX_SEGMENT && SEGMENT_PATTERN.match(value);
  }

  /** Keep `--fps` inside {@link MIN_FPS}..{@link MAX_FPS} before anything reads it. */
  static function clampFps(fps:Int):Int
  {
    if (fps < MIN_FPS) return MIN_FPS;
    return fps > MAX_FPS ? MAX_FPS : fps;
  }

  /** First line of a message, so a rejection stays one log line long. */
  static function firstLine(message:String):String
  {
    if (message == null) return 'unusable launch arguments';
    final text:String = StringTools.trim(message);
    final breakAt:Int = text.indexOf('\n');
    return (breakAt >= 0 ? text.substring(0, breakAt) : text);
  }
}
