import backend.CommandLine;
import backend.LaunchOptions;

/**
 * Contract tests for the command line launch options
 * (`source/backend/CommandLine.hx`), parsed by docopt-ng.
 *
 * Flixel-free on purpose: deciding what `--fullscreen` or `--song=bopeebo`
 * means does not need OpenFL, so the whole grammar runs in the Haxe
 * interpreter. Run with `bash tests/haxe/run-command-line.sh`.
 *
 * The runner compiles this spec twice, the way `run-launch-state.sh` does for
 * the build flags: once with `-D CLI_OPTIONS_ALLOWED` (desktop and mobile,
 * where docopt-ng is on the classpath) and once without it (html5, Flash and
 * AIR, where the parser must degrade to "nothing requested" instead of
 * failing the build). The integration sites that need the whole game are
 * guarded by `CommandLineWiringSpec`.
 */
class CommandLineSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  /** Parse a vector the way a caller does, without leaking state between cases. */
  static function parse(args:Array<String>):LaunchOptions
  {
    CommandLine.reset();
    return CommandLine.parse(args);
  }

  static function main():Void
  {
    #if CLI_OPTIONS_ALLOWED
    anIconLaunchRequestsNothing();
    helpAndVersionAreAnsweredNotPlayed();
    helpTextDocumentsEveryOption();
    windowModeFlagsHaveAFixedPrecedence();
    framerateIsOptionalAndClamped();
    launchScreenFlagsFeedLaunchState();
    legacySpellingsStillWork();
    songAndModBecomePhoenixRoutes();
    diagnosticsFlagsReachTheirSystems();
    anUnusableVectorStillBootsTheGame();
    deeplinksCanBeRefused();
    parseDoesNotConsumeTheVector();
    loadRemembersTheVector();
    describeSummarizesTheSession();
    Sys.println('CommandLineSpec: PASS (docopt-ng)');
    #else
    aBuildWithoutTheFlagRequestsNothing();
    Sys.println('CommandLineSpec: PASS (CLI_OPTIONS_ALLOWED off)');
    #end
  }

  #if CLI_OPTIONS_ALLOWED
  /** Double-clicking the executable must behave exactly like yesterday. */
  static function anIconLaunchRequestsNothing():Void
  {
    final options:LaunchOptions = parse([]);
    equal(options.help, false, 'no --help');
    equal(options.version, false, 'no --version');
    equal(options.fullscreen, false, 'no --fullscreen');
    equal(options.windowed, false, 'no --windowed');
    equal(options.borderless, false, 'no --borderless');
    equal(options.fps, null, 'no --fps');
    equal(options.freeplay, false, 'no --freeplay');
    equal(options.menu, false, 'no --menu');
    equal(options.profile, false, 'no --profile');
    equal(options.vlog, false, 'no --vlog');
    equal(options.safeMode, false, 'no --safe-mode');
    equal(options.troll, false, 'no --troll');
    equal(options.noDeeplinks, false, 'no --no-deeplinks');
    equal(options.uris.length, 0, 'no phoenix:// link');
    equal(options.error, null, 'an empty vector is not an error');
    equal(CommandLine.windowModeOverride(options), '', 'the saved window mode stays in charge');
    equal(CommandLine.framerate(60, options), 60, 'the saved framerate stays in charge');
    equal(CommandLine.freeplayOverride(options), null, 'LaunchState keeps the build flags');
    equal(CommandLine.menuOverride(options), null, 'LaunchState keeps the build flags');
    equal(CommandLine.deeplinks(options).length, 0, 'DeepLinks receives nothing');
    equal(CommandLine.describe(options), 'none', 'the vlog says nothing was requested');
  }

  /** `--help` and `--version` are answered by `Main` before a window opens. */
  static function helpAndVersionAreAnsweredNotPlayed():Void
  {
    equal(parse(['--help']).help, true, '--help asks for the usage text');
    equal(parse(['-h']).help, true, '-h asks for the usage text');
    equal(parse(['--version']).version, true, '--version asks for the version');
    equal(parse(['--fullscreen', '--help']).help, true, '--help wins over the other options');

    // The record only *asks*: nothing here may start the game or exit.
    equal(parse(['--help']).fullscreen, false, '--help alone requests no window mode');
    equal(CommandLine.versionText('0.0.1'), '${CommandLine.PROGRAM_NAME} 0.0.1', 'the version line names the executable');
    equal(CommandLine.versionText(null), '${CommandLine.PROGRAM_NAME} unknown', 'a build without -Dcommit still prints a version line');
  }

  /** The help text is the docstring docopt parsed, so it cannot go stale. */
  static function helpTextDocumentsEveryOption():Void
  {
    final help:String = CommandLine.helpText();
    check(help.indexOf('Usage:') >= 0, 'help has a usage section');
    check(help.indexOf('Options:') >= 0, 'help has an options section');
    for (option in [
      '--help', '--version', '--windowed', '--fullscreen', '--borderless', '--fps=', '--freeplay', '--menu', '--song=', '--mod=', '--profile', '--vlog',
      '--safe-mode', '--troll', '--no-deeplinks'
    ])
      check(help.indexOf(option) >= 0, 'help documents $option');
    for (short in ['-h ', '-w ', '-f ', '-b '])
      check(help.indexOf(short) >= 0, 'help documents the short spelling $short');
    check(help.indexOf(CommandLine.PROGRAM_NAME) >= 0, 'help names the executable');
  }

  /** Window mode: three flags, one decision, never argument order. */
  static function windowModeFlagsHaveAFixedPrecedence():Void
  {
    equal(CommandLine.windowModeOverride(parse(['--windowed'])), CommandLine.MODE_WINDOWED, '--windowed');
    equal(CommandLine.windowModeOverride(parse(['-w'])), CommandLine.MODE_WINDOWED, '-w is --windowed');
    equal(CommandLine.windowModeOverride(parse(['--fullscreen'])), CommandLine.MODE_FULLSCREEN, '--fullscreen');
    equal(CommandLine.windowModeOverride(parse(['-f'])), CommandLine.MODE_FULLSCREEN, '-f is --fullscreen');
    equal(CommandLine.windowModeOverride(parse(['--borderless'])), CommandLine.MODE_BORDERLESS, '--borderless');
    equal(CommandLine.windowModeOverride(parse(['-b'])), CommandLine.MODE_BORDERLESS, '-b is --borderless');

    // Conflicts resolve in a fixed order, like -DFREEPLAY against -DMENU.
    equal(CommandLine.windowModeOverride(parse(['--windowed', '--fullscreen'])), CommandLine.MODE_FULLSCREEN, 'fullscreen beats windowed');
    equal(CommandLine.windowModeOverride(parse(['--fullscreen', '--windowed'])), CommandLine.MODE_FULLSCREEN, 'the order of the arguments changes nothing');
    equal(CommandLine.windowModeOverride(parse(['--windowed', '--borderless'])), CommandLine.MODE_BORDERLESS, 'borderless beats windowed');
    equal(CommandLine.windowModeOverride(parse(['--borderless', '--fullscreen'])), CommandLine.MODE_FULLSCREEN, 'fullscreen beats borderless');

    // One dash in front of a whole word is a cluster to docopt; a player never
    // means that, so the long spelling is what it becomes.
    equal(CommandLine.windowModeOverride(parse(['-fullscreen'])), CommandLine.MODE_FULLSCREEN, '-fullscreen is accepted as --fullscreen');
    equal(parse(['-wfb']).fullscreen, true, '-wfb is the -w -f -b cluster');
  }

  /** `--fps` overrides the saved gameplay rate, inside the engine's own band. */
  static function framerateIsOptionalAndClamped():Void
  {
    equal(parse(['--fps=144']).fps, 144, '--fps=144');
    equal(parse(['--fps', '240']).fps, 240, '--fps accepts a separate value');
    equal(CommandLine.framerate(60, parse(['--fps=144'])), 144, 'the override wins over the boot default');
    equal(CommandLine.framerateOverride(parse([])), null, 'no --fps means "keep the saved rate"');

    equal(parse(['--fps=0']).fps, CommandLine.MIN_FPS, 'zero is clamped to the minimum');
    equal(parse(['--fps=-30']).fps, CommandLine.MIN_FPS, 'a negative rate is clamped to the minimum');
    equal(parse(['--fps=99999']).fps, CommandLine.MAX_FPS, 'an absurd rate is clamped to the maximum');

    final unusable:LaunchOptions = parse(['--fps=fast']);
    equal(unusable.fps, null, 'a rate that is not a number is dropped');
    check(unusable.error != null && unusable.error.indexOf('--fps') >= 0, 'and reported instead of being silent');
    equal(CommandLine.framerate(60, unusable), 60, 'so the saved rate stays in charge');
    equal(parse(['--fps=60.5']).fps, null, 'a fractional rate is reported, not truncated');
  }

  /** The runtime twins of `-DFREEPLAY` / `-DMENU` feed the same resolver. */
  static function launchScreenFlagsFeedLaunchState():Void
  {
    final freeplay:LaunchOptions = parse(['--freeplay']);
    equal(freeplay.freeplay, true, '--freeplay is read');
    equal(CommandLine.freeplayOverride(freeplay), true, 'and handed to LaunchState.resolve as an override');
    equal(CommandLine.menuOverride(freeplay), null, 'without touching --menu');

    final menu:LaunchOptions = parse(['--menu']);
    equal(CommandLine.menuOverride(menu), true, '--menu is handed over as an override');
    equal(CommandLine.freeplayOverride(menu), null, 'without touching --freeplay');

    // Both flags: LaunchState.resolve already lets freeplay win, so the command
    // line must not invent a second conflict rule.
    final both:LaunchOptions = parse(['--freeplay', '--menu']);
    equal(CommandLine.freeplayOverride(both), true, 'a conflict still reports --freeplay');
    equal(CommandLine.menuOverride(both), true, 'and --menu, and the resolver decides');
  }

  /** Spellings that existed before docopt must keep working. */
  static function legacySpellingsStillWork():Void
  {
    equal(parse(['-troll']).troll, true, '-troll still enables super danger mode');
    equal(parse(['--troll']).troll, true, '--troll is the documented spelling');
    equal(parse(['-profile']).profile, true, '-profile still enables the frame profiler');
    equal(parse(['--profile']).profile, true, '--profile is the documented spelling');
    equal(parse(['--frame-profiler']).profile, true, '--frame-profiler still enables it');
    equal(CommandLine.normalizeLegacy(['-troll', '--frame-profiler', '--vlog']).join(' '), '--troll --profile --vlog',
      'normalization only rewrites what it knows');
  }

  /** `--song` / `--mod` reuse the validated phoenix:// routes (URI.MD). */
  static function songAndModBecomePhoenixRoutes():Void
  {
    equal(parse(['--song=bopeebo']).uris.join(','), 'phoenix://song/bopeebo', '--song opens the song route');
    equal(parse(['--mod=mymod']).uris.join(','), 'phoenix://mod/mymod', '--mod opens the mod route');
    equal(parse(['--mod=mymod', '--song=bopeebo']).uris.join(','), 'phoenix://mod/mymod/song/bopeebo',
      'both together open the mod song route');
    equal(parse(['phoenix://menu/mods']).uris.join(','), 'phoenix://menu/mods', 'a positional link is kept');
    equal(parse(['phoenix://menu/mods', '--song=fresh']).uris.join(','), 'phoenix://menu/mods,phoenix://song/fresh',
      'the option is queued last, so it wins the link DeepLinks keeps');

    final badSong:LaunchOptions = parse(['--song=bad name!']);
    equal(badSong.song, null, 'a song name that is not a URI segment is dropped');
    equal(badSong.uris.length, 0, 'and never reaches DeepLinks');
    check(badSong.error != null && badSong.error.indexOf('--song') >= 0, 'but it is reported');
    check(parse(['--mod=a/b']).mod == null, 'a mod id with a slash is dropped');
    check(parse(['--song=']).song == null, 'an empty --song is dropped');
  }

  /** `--profile`, `--vlog` and `--safe-mode` are session switches, not prefs. */
  static function diagnosticsFlagsReachTheirSystems():Void
  {
    equal(parse(['--profile']).profile, true, '--profile turns the frame profiler on');
    equal(parse(['--vlog']).vlog, true, '--vlog turns the verbose log on');
    equal(parse(['--safe-mode']).safeMode, true, '--safe-mode asks for the recovery screen');
    equal(parse(['--safe-mode', '--vlog']).safeMode, true, 'the three combine');
    equal(parse(['--safe-mode', '--vlog']).vlog, true, 'without excluding each other');
  }

  /** A bad shortcut must never be able to stop the engine from starting. */
  static function anUnusableVectorStillBootsTheGame():Void
  {
    final unknown:LaunchOptions = parse(['--nope']);
    check(unknown.error != null, 'an unknown flag is reported');
    equal(unknown.fullscreen, false, 'and every option falls back to its default');
    equal(unknown.uris.length, 0, 'nothing is queued for DeepLinks');

    final stray:LaunchOptions = parse(['banana']);
    check(stray.error != null && stray.error.indexOf('banana') >= 0, 'a stray argument is reported by name');
    equal(stray.uris.length, 0, 'and is not handed to DeepLinks as a link');

    // The important case: Windows starts the executable with the link as an
    // argument, so a link must survive a vector the parser could not use.
    final mixed:LaunchOptions = parse(['--nope', 'phoenix://menu/mods']);
    check(mixed.error != null, 'the unknown flag is still reported');
    equal(mixed.uris.join(','), 'phoenix://menu/mods', 'but the protocol launch still arrives');
    equal(mixed.raw.join(' '), '--nope phoenix://menu/mods', 'the vector is kept for the diagnostics report');
  }

  /** `--no-deeplinks` is the opt-out for a link loop. */
  static function deeplinksCanBeRefused():Void
  {
    equal(CommandLine.deeplinks(parse(['phoenix://menu/mods'])).join(','), 'phoenix://menu/mods', 'links are delivered by default');
    equal(CommandLine.deeplinks(parse(['--no-deeplinks', 'phoenix://menu/mods'])).length, 0, '--no-deeplinks withholds them');
    equal(parse(['--no-deeplinks', 'phoenix://menu/mods']).uris.length, 1, 'while the record still shows what was passed');
  }

  /** docopt consumes the array it parses; the caller's vector must survive. */
  static function parseDoesNotConsumeTheVector():Void
  {
    final args:Array<String> = ['--fullscreen', 'phoenix://menu/mods'];
    parse(args);
    equal(args.length, 2, 'parse does not consume the vector it was given');
    equal(args[0], '--fullscreen', 'parse does not rewrite the vector it was given');
    equal(parse(args).fullscreen, true, 'so parsing the same vector twice still works');
  }

  /** `load()` is what `Main` calls; `options` is what everybody else reads. */
  static function loadRemembersTheVector():Void
  {
    CommandLine.reset();
    CommandLine.load(['--menu']);
    equal(CommandLine.options.menu, true, 'load() remembers the vector for every later reader');
    CommandLine.reset();
    CommandLine.load(['--freeplay']);
    equal(CommandLine.options.freeplay, true, 'a second load() replaces the first');
    equal(CommandLine.options.menu, false, 'and does not keep the previous options');

    // The process vector is whatever the platform handed us; reading it must
    // not throw, even when it is the interpreter's own command line.
    CommandLine.reset();
    check(CommandLine.options != null, 'reading options parses the process vector on demand');
    check(CommandLine.describe() != null, 'and it can always be described');
  }

  /** The vlog line a support request is built from. */
  static function describeSummarizesTheSession():Void
  {
    final summary:String = CommandLine.describe(parse(['--fullscreen', '--fps=240', '--profile', 'phoenix://song/fresh']));
    check(summary.indexOf('--fullscreen') >= 0, 'the summary names the window mode');
    check(summary.indexOf('--fps=240') >= 0, 'the summary names the framerate');
    check(summary.indexOf('--profile') >= 0, 'the summary names the profiler');
    check(summary.indexOf('phoenix://song/fresh') >= 0, 'the summary names the link');
    check(CommandLine.describe(parse(['--nope'])).indexOf('ignored:') >= 0, 'the summary says what was dropped');
  }
  #else
  /**
   * Without the feature flag there is no docopt on the classpath (html5,
   * Flash, AIR): the parser must stay inert instead of failing the build, and
   * a `phoenix://` launch must still be delivered.
   */
  static function aBuildWithoutTheFlagRequestsNothing():Void
  {
    final options:LaunchOptions = parse(['--fullscreen', '--fps=144', '--freeplay', 'phoenix://menu/mods']);
    equal(options.fullscreen, false, 'no window mode is requested');
    equal(options.fps, null, 'no framerate is requested');
    equal(options.freeplay, false, 'no launch screen is requested');
    check(options.error != null, 'the build says why nothing was applied');
    equal(options.uris.join(','), 'phoenix://menu/mods', 'a protocol launch still reaches DeepLinks');
    equal(CommandLine.windowModeOverride(options), '', 'the saved window mode stays in charge');
    equal(CommandLine.framerate(60, options), 60, 'the saved framerate stays in charge');
    equal(CommandLine.freeplayOverride(options), null, 'LaunchState keeps the build flags');
    equal(CommandLine.menuOverride(options), null, 'LaunchState keeps the build flags');
    check(CommandLine.describe(options).indexOf('ignored:') >= 0, 'the only thing to report is why nothing was applied');
    check(CommandLine.helpText().indexOf('Usage:') >= 0, 'the usage text still exists for the docs');
  }
  #end
}
