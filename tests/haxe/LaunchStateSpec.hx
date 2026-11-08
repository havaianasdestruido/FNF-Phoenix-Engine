import backend.LaunchState;
import backend.LaunchTarget;

/**
 * Contract tests for the `-DFREEPLAY` / `-DMENU` launch flags
 * (`source/backend/LaunchState.hx`).
 *
 * Flixel-free on purpose: the flags decide which *state* `InitState` switches
 * to, and that decision does not need OpenFL to be checked. Run with
 * `bash tests/haxe/run-launch-state.sh`.
 */
class LaunchStateSpec
{
  static function check(ok:Bool, label:String):Void
  {
    if (!ok) throw label;
  }

  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    defaultsWithoutFlags();
    explicitFlagsWin();
    conflictingFlagsAreDeterministic();
    namesAreDistinct();
    Sys.println('LaunchStateSpec: PASS');
  }

  /** A normal build keeps the splash/title flow the game already had. */
  static function defaultsWithoutFlags():Void
  {
    // The runner compiles this spec without the defines, so the statics must
    // report "off" and the plain flow must not depend on them.
    equal(LaunchState.FREEPLAY_BUILD, false, '-DFREEPLAY is off in this build');
    equal(LaunchState.MENU_BUILD, false, '-DMENU is off in this build');

    equal(LaunchState.resolve(false), LaunchTarget.SPLASH, 'splash first by default');
    equal(LaunchState.resolve(true), LaunchTarget.TITLE, 'disableSplash skips the splash');

    // Passing the defines explicitly must behave like the compiled default.
    equal(LaunchState.resolve(false, false, false), LaunchTarget.SPLASH, 'explicit off keeps the splash');
    equal(LaunchState.resolve(true, false, false), LaunchTarget.TITLE, 'explicit off keeps the title');
  }

  /** Each flag jumps straight to its screen, past the splash and the title. */
  static function explicitFlagsWin():Void
  {
    equal(LaunchState.resolve(false, true, false), LaunchTarget.FREEPLAY, '-DFREEPLAY goes to freeplay');
    equal(LaunchState.resolve(false, false, true), LaunchTarget.MAIN_MENU, '-DMENU goes to the main menu');

    // The splash preference must not push a launch flag back to the title.
    equal(LaunchState.resolve(true, true, false), LaunchTarget.FREEPLAY, 'disableSplash keeps -DFREEPLAY');
    equal(LaunchState.resolve(true, false, true), LaunchTarget.MAIN_MENU, 'disableSplash keeps -DMENU');
  }

  /** project.hxp rejects both flags; a mis-built binary still resolves one way. */
  static function conflictingFlagsAreDeterministic():Void
  {
    check(LaunchState.hasConflict(true, true), 'both flags conflict');
    check(!LaunchState.hasConflict(true, false), 'only -DFREEPLAY is fine');
    check(!LaunchState.hasConflict(false, true), 'only -DMENU is fine');
    check(!LaunchState.hasConflict(), 'no flags is fine');

    equal(LaunchState.resolve(false, true, true), LaunchTarget.FREEPLAY, 'freeplay wins a conflict');
  }

  /** The build log and the spec both read these names. */
  static function namesAreDistinct():Void
  {
    final seen:Array<String> = [];
    for (target in [LaunchTarget.SPLASH, LaunchTarget.TITLE, LaunchTarget.MAIN_MENU, LaunchTarget.FREEPLAY])
    {
      final name:String = LaunchState.targetName(target);
      check(name != null && name.length > 0, 'every target has a name');
      check(!seen.contains(name), 'target names are unique (' + name + ')');
      seen.push(name);
    }
  }
}
