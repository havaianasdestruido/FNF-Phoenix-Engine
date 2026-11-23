package backend;

/**
 * Everything {@link CommandLine} read from the launch arguments.
 *
 * A plain record on purpose: no Flixel, OpenFL or Lime type appears in it, so
 * the parser and every caller that only needs a decision (window mode,
 * framerate, first screen) can be exercised by
 * `tests/haxe/run-command-line.sh` in the Haxe interpreter.
 *
 * Every field defaults to "not requested" (`false`, `null`, `[]`), which makes
 * an icon launch indistinguishable from a launch with no recognized option.
 *
 * Not to be confused with `backend.LaunchState`: that one resolves the
 * *compile-time* `-DFREEPLAY` / `-DMENU` build flags, while these are the
 * *runtime* options of the current process.
 */
typedef LaunchOptions =
{
  /** `-h` / `--help`: print the usage text and exit before the window opens. */
  var help:Bool;

  /** `--version`: print the engine version and exit before the window opens. */
  var version:Bool;

  /** `-w` / `--windowed`: force windowed mode for this session. */
  var windowed:Bool;

  /** `-f` / `--fullscreen`: force exclusive fullscreen for this session. */
  var fullscreen:Bool;

  /** `-b` / `--borderless`: force borderless fullscreen for this session. */
  var borderless:Bool;

  /** `--fps=<n>`: gameplay framerate for this session, or `null` to keep the saved one. */
  var fps:Null<Int>;

  /** `--freeplay`: boot straight into `FreeplayState`, like `-DFREEPLAY`. */
  var freeplay:Bool;

  /** `--menu`: boot straight into `MainMenuState`, like `-DMENU`. */
  var menu:Bool;

  /** `--song=<name>`: song route to open after boot, or `null` when not requested. */
  var song:Null<String>;

  /** `--mod=<id>`: mod route to open after boot, or `null` when not requested. */
  var mod:Null<String>;

  /** `--profile`: enable the frame profiler and export its log on exit. */
  var profile:Bool;

  /** `--vlog`: write the verbose log for this session. */
  var vlog:Bool;

  /** `--safe-mode`: boot into the recovery screen, like a crash loop would. */
  var safeMode:Bool;

  /** `--troll` (legacy `-troll`): allow `CoolUtil.selfDestruct()`. */
  var troll:Bool;

  /** `--no-deeplinks`: ignore every `phoenix://` URI on the command line. */
  var noDeeplinks:Bool;

  /**
   * `phoenix://` links to open after boot: the positional arguments first,
   * then the routes synthesized from `--song` / `--mod`. `DeepLinks.receive`
   * keeps the last one it is given, so an explicit `--song` wins over a link.
   */
  var uris:Array<String>;

  /** The argument vector as it was handed to the parser, before normalization. */
  var raw:Array<String>;

  /**
   * What the parser had to reject or ignore (`null` when every argument was
   * understood): the usage error of a vector docopt refused, or the values it
   * could not use (`--fps=fast`). The game boots either way — a stale
   * shortcut, or a launcher that appends its own arguments, must not be able
   * to stop the engine from starting.
   */
  var error:Null<String>;
}
