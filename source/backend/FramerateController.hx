package backend;

import flixel.FlxG;
import flixel.FlxState;

/**
 * Applies the frame rate the current screen is supposed to run at.
 *
 * Two rates exist (see `backend.FramerateMath`): `ClientPrefs.framerate`
 * for gameplay and `ClientPrefs.menuFramerate` for everything else, so an
 * idle menu does not inherit a 1000 FPS gameplay cap.
 *
 * Called from:
 *
 * - `backend.MusicBeatState.create()` and the raw `FlxState` states
 *   (`states.InitState`, `states.RecoveryState`) via `applyForState()`;
 * - `backend.ClientPrefs.loadPrefs()` for the boot-time gameplay rate;
 * - Options -> Graphics rows (`menuFramerate`, `focusLostFramerate`);
 * - Settings backup import (`backend.SettingsBackup.applyImmediately()`).
 *
 * Every write goes through `FramerateMath.clamp()`, so hand-edited saves
 * cannot produce a zero/negative rate or dodge the Uncapped FPS cap.
 */
class FramerateController
{
  /**
   * Applies the rate for the state that is being created.
   *
   * Only `play.PlayState` keeps the gameplay rate; menus, editors, loading
   * screens and every other state run at the menu rate. PlayState also
   * re-applies its rate when it is created, so switching between songs at a
   * different saved value is consistent.
   */
  public static function applyForState(state:FlxState):Void
  {
    final isGameplay:Bool = state != null && Std.isOfType(state, play.PlayState);
    apply(FramerateMath.stateRate(isGameplay, ClientPrefs.framerate, ClientPrefs.menuFramerate));
  }

  /**
   * Sets both Flixel rates (raising `updateFramerate` first when growing,
   * matching `ClientPrefs.loadPrefs()`) and the frame profiler's target.
   */
  public static function apply(fps:Int):Void
  {
    final target:Int = FramerateMath.clamp(fps, ClientPrefs.uncappedFps);

    if (target > FlxG.drawFramerate)
    {
      FlxG.updateFramerate = target;
      FlxG.drawFramerate = target;
    }
    else
    {
      FlxG.drawFramerate = target;
      FlxG.updateFramerate = target;
    }

    debug.FrameProfiler.setTargetFps(target);
  }

  /**
   * Applies the background (window unfocused) rate.
   *
   * Safe to call before `FlxG.game` exists (headless tests): the value is
   * then left alone. `states.InitState` applies the saved value once the
   * save file has been read; the Options -> Graphics row applies it live.
   */
  public static function applyFocusLost(fps:Int):Void
  {
    final target:Int = FramerateMath.clamp(fps, ClientPrefs.uncappedFps);
    if (FlxG.game != null) FlxG.game.focusLostFramerate = target;
  }
}
