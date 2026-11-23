import sys.io.File;
import sys.FileSystem;
import backend.CommandLine;

/**
 * Guards the integration sites of the launch options (`docs/CLI.md`) that
 * cannot run without the whole game: `Main`'s boot order, the first screen,
 * the saved preferences a launch option overrides, the frame profiler and the
 * `phoenix://` hand-off — plus the dependency and documentation promises the
 * feature makes (`AGENTS.md` §8 rule 7, TODO §33.4).
 *
 * The runner compiles this spec without `-D CLI_OPTIONS_ALLOWED`, which is
 * enough to read {@link CommandLine.USAGE}: the option table the docs and the
 * build files are checked against. Run with
 * `bash tests/haxe/run-command-line.sh`.
 */
class CommandLineWiringSpec
{
  static function check(value:Bool, label:String):Void
  {
    if (!value) throw label;
  }

  static function text(path:String):String
  {
    check(FileSystem.exists(path), 'missing file: $path');
    return File.getContent(path);
  }

  static function contains(source:String, needle:String, label:String):Void
  {
    check(source.indexOf(needle) >= 0, label);
  }

  static function absent(source:String, needle:String, label:String):Void
  {
    check(source.indexOf(needle) < 0, label);
  }

  static function slice(source:String, start:String, end:String):String
  {
    final from:Int = source.indexOf(start);
    check(from >= 0, 'missing source section: $start');
    final until:Int = source.indexOf(end, from + start.length);
    check(until > from, 'missing end of source section: $end');
    return source.substring(from, until);
  }

  static function main():Void
  {
    mainParsesBeforeTheWindowOpens();
    firstScreenReadsTheLaunchOptions();
    preferencesAreOverriddenNotRewritten();
    profilerAndDeeplinksReadOneFlag();
    dependencyIsPinnedEverywhere();
    docsCoverEveryOption();
    Sys.println('CommandLineWiringSpec: PASS');
  }

  /** `Main` owns the parse, the two information requests and safe mode. */
  static function mainParsesBeforeTheWindowOpens():Void
  {
    final main = text('source/Main.hx');
    final boot = slice(main, 'public static function main():Void', 'Lib.current.addChild(new Main());');
    contains(boot, 'backend.CommandLine.load();', 'main() parses the launch options before anything else');
    contains(boot, 'answerInformationRequest()', 'main() answers --help/--version before creating the window');
    check(boot.indexOf('backend.CommandLine.load();') < boot.indexOf('answerInformationRequest()'),
      'the options are parsed before they are answered');

    final answer = slice(main, 'static function answerInformationRequest():Bool', '\n  }');
    contains(answer, 'CommandLine.helpText()', '--help prints the docstring docopt parsed');
    contains(answer, 'CommandLine.versionText(', '--version prints the engine version');
    contains(answer, 'Sys.exit(0)', 'both exit cleanly instead of booting the game');

    // `-troll` used to be read straight from Sys.args(); one reader now.
    contains(main, 'public static var superDangerMode(get, never):Bool;', 'superDangerMode is a getter, not a static initializer');
    contains(main, 'backend.CommandLine.options.troll', 'super danger mode comes from the parsed options');
    absent(main, 'Sys.args().contains("-troll")', 'the hand-rolled -troll scan is gone');
    absent(main, 'Sys.args()', 'Main no longer reads the argument vector itself');

    contains(main, 'backend.CommandLine.options.safeMode', '--safe-mode joins the crash-loop recovery boot');
    contains(main, 'backend.CommandLine.options.vlog', '--vlog can turn the verbose log on for one session');
    contains(main, "backend.VLog.log('CLI', backend.CommandLine.describe())", 'the vlog records what was requested');
    contains(main, 'game.framerate = backend.CommandLine.framerate(game.framerate);', '--fps sets the rate FlxGame boots with');
    contains(main, 'backend.CommandLine.windowModeOverride()', 'the window mode override is read before the window is created');

    // The recovery screen decision must stay one value, or the initial state
    // and the diagnostics would disagree about this boot.
    final safeMode = slice(main, 'static function safeModeBoot():Bool', '\n  }');
    contains(safeMode, 'backend.RecoveryBoot.failures >= backend.RecoveryBoot.THRESHOLD', 'a crash loop still forces safe mode');
    contains(safeMode, 'backend.CommandLine.options.safeMode', 'and so does --safe-mode');
    check(main.split('safeModeBoot()').length >= 4, 'every recovery decision reads safeModeBoot()');
  }

  /** `--freeplay` / `--menu` go through the resolver the build flags use. */
  static function firstScreenReadsTheLaunchOptions():Void
  {
    final state = text('source/states/InitState.hx');
    contains(state, 'LaunchState.resolve(ClientPrefs.disableSplash, backend.CommandLine.freeplayOverride(), backend.CommandLine.menuOverride())',
      'InitState hands the launch options to the existing resolver');
    check(state.split('LaunchState.resolve(').length == 2, 'there is still exactly one place that picks the first screen');

    final resolver = text('source/backend/LaunchState.hx');
    contains(resolver, 'freeplay:Null<Bool> = null, menu:Null<Bool> = null', 'the resolver still accepts runtime overrides');
  }

  /** A launch option is a session override: the save file keeps the player's choice. */
  static function preferencesAreOverriddenNotRewritten():Void
  {
    final prefs = text('source/backend/ClientPrefs.hx');

    final load = slice(prefs, 'final requestedFps:Null<Int> = CommandLine.framerateOverride();', 'FramerateController.apply(framerate);');
    contains(load, 'CommandLine.savedFramerate = framerate;', 'the saved rate is remembered before it is overridden');
    contains(load, 'framerate = FramerateMath.clamp(requestedFps, uncappedFps);', 'and the override is clamped like a saved one');

    contains(prefs, 'Reflect.setField(FlxG.save.data, field, savedValueOf(field));', 'saving goes through the override guard');
    final guard = slice(prefs, 'private static function savedValueOf(field:String):Dynamic', '\n\t}');
    contains(guard, 'CommandLine.savedFramerate', 'the guard writes the player\'s own rate back');
    contains(guard, 'live == requestedFps', 'and stops guarding once the player picks a rate in Options');

    final window = slice(prefs, 'public static function applyWindowModePreference():Void', '\n  }');
    contains(window, 'CommandLine.windowModeOverride()', 'the window mode launch option is applied here');
    contains(window, 'windowMode = WindowMode.normalize(windowMode);', 'the saved preference is still normalized first');
    contains(window, 'WindowMode.apply(requestedMode.length > 0 ? requestedMode : windowMode)',
      'the saved mode - not a hard-coded default - is applied when no option was given');
    absent(window, 'windowMode = requestedMode', 'the override never rewrites the saved preference');
  }

  /** One flag, one reader: the profiler and the deeplink hand-off. */
  static function profilerAndDeeplinksReadOneFlag():Void
  {
    final profiler = text('source/debug/FrameProfiler.hx');
    contains(profiler, 'backend.CommandLine.options.profile', 'the frame profiler reads --profile');
    absent(profiler, 'Sys.args()', 'and no longer scans the argument vector itself');
    absent(profiler, '"--frame-profiler"', 'the legacy spellings live in CommandLine.normalizeLegacy');

    final links = text('source/backend/deeplink/DeepLinks.hx');
    contains(links, 'backend.CommandLine.deeplinks()', 'DeepLinks takes the links the launch options collected');
    absent(links, 'for (argument in Sys.args()) receive(argument);', 'the raw argument scan is gone');
    check(links.split('backend.CommandLine.deeplinks()').length >= 3,
      'Windows protocol launches and terminal launches both go through it');
    contains(links, 'PhoenixURI', 'each link is still validated by the URI parser');
  }

  /** `AGENTS.md` §8 rule 7 and TODO §33.4: pinned, in every dialect, gated, in CI. */
  static function dependencyIsPinnedEverywhere():Void
  {
    final manifest = text('hmm.json');
    contains(manifest, '"name":"docopt-ng"', 'hmm.json declares docopt-ng');
    check(~/{"name":"docopt-ng","type":"haxelib","version":"[0-9]+\.[0-9]+\.[0-9]+"}/.match(manifest),
      'hmm.json pins docopt-ng to a registry version');

    // Every setup dialect, so a Windows checkout and a Linux CI runner install
    // the same parser (tools/check_dependencies.py only polices git deps).
    for (script in ['setup/unix.sh', 'setup/unix.ps1', 'setup/unix.bat', 'setup/windows.sh', 'setup/windows.ps1', 'setup/windows.bat'])
    {
      final setup = text(script);
      contains(setup, 'haxelib install docopt-ng 0.9.1', '$script installs docopt-ng');
      contains(setup, '--skip-dependencies', '$script skips utest, which only docopt-ng\'s own tests need');
    }

    final project = text('project.hxp');
    contains(project, 'static final CLI_OPTIONS_ALLOWED:FeatureFlag = "CLI_OPTIONS_ALLOWED";', 'the feature flag exists');
    contains(project, 'CLI_OPTIONS_ALLOWED.apply(this,', 'the flag has a default per target');
    final haxelibs = slice(project, 'function configureHaxelibs()', 'function configureAssets()');
    contains(haxelibs, "if (CLI_OPTIONS_ALLOWED.isEnabled(this))\n\t\t\taddHaxelib('docopt-ng');",
      'docopt-ng is only on the classpath of builds that parse a command line');

    final checks = text('.github/workflows/checks.yml');
    contains(checks, 'tests/haxe/run-command-line.sh', 'CI runs the launch options specs');
    contains(checks, 'haxelib install docopt-ng', 'CI installs the parser the spec needs');
  }

  /** The player-facing reference must list what the parser accepts. */
  static function docsCoverEveryOption():Void
  {
    final docs = text('docs/CLI.md');
    contains(docs, 'docopt', 'the guide names the parser');
    contains(docs, CommandLine.PROGRAM_NAME, 'the guide uses the real executable name');

    // Every long option in the docstring, read from the docstring itself so a
    // new flag cannot be added to one file and forgotten in the other.
    final pattern:EReg = ~/--([a-z0-9][a-z0-9-]*)/;
    var rest:String = CommandLine.USAGE;
    var documented:Int = 0;
    while (pattern.match(rest))
    {
      final option:String = '--' + pattern.matched(1);
      contains(docs, option, 'docs/CLI.md documents $option');
      documented++;
      rest = pattern.matchedRight();
    }
    check(documented >= 14, 'the whole option table was checked ($documented options)');

    for (short in ['-h', '-w', '-f', '-b'])
      contains(docs, short, 'docs/CLI.md documents the short spelling $short');
    contains(docs, '-troll', 'docs/CLI.md keeps the legacy -troll spelling discoverable');
    contains(docs, 'phoenix://', 'docs/CLI.md explains the positional links');

    // Reachable from the two places a player or a modder would look first.
    contains(text('BUILDING.md'), 'docs/CLI.md', 'BUILDING.md links to the guide');
    contains(text('URI.MD'), 'docs/CLI.md', 'URI.MD links to the guide');
  }
}
