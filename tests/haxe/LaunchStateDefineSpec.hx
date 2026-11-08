import backend.LaunchState;
import backend.LaunchTarget;

/**
 * Checks that the `-DFREEPLAY` / `-DMENU` defines actually reach the runtime
 * statics in `source/backend/LaunchState.hx`.
 *
 * Compiled twice by `tests/haxe/run-launch-state.sh`, once per define.
 */
class LaunchStateDefineSpec
{
  static function equal<T>(actual:T, expected:T, label:String):Void
  {
    if (actual != expected) throw '$label: expected $expected, got $actual';
  }

  static function main():Void
  {
    #if FREEPLAY
    equal(LaunchState.FREEPLAY_BUILD, true, '-DFREEPLAY define is visible');
    equal(LaunchState.MENU_BUILD, false, '-DFREEPLAY does not set -DMENU');
    equal(LaunchState.resolve(false), LaunchTarget.FREEPLAY, '-DFREEPLAY boots freeplay');
    #elseif MENU
    equal(LaunchState.MENU_BUILD, true, '-DMENU define is visible');
    equal(LaunchState.FREEPLAY_BUILD, false, '-DMENU does not set -DFREEPLAY');
    equal(LaunchState.resolve(false), LaunchTarget.MAIN_MENU, '-DMENU boots the main menu');
    #else
    throw 'compile this spec with -DFREEPLAY or -DMENU';
    #end
    Sys.println('LaunchStateDefineSpec: PASS');
  }
}
