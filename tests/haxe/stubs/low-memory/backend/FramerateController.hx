package backend;

/** Test double for `backend.FramerateController` used by `LowMemorySpec`. */
class FramerateController
{
  public static var stateApplyCount:Int = 0;
  public static var lastMenuFramerate:Int = 60;
  public static var lastFocusLostFramerate:Int = 60;

  /**
   * Records a per-state framerate sync.
   *
   * @param state Active state under test.
   * @return Applied cap for the state.
   */
  public static function applyForState(state:Dynamic):Int
  {
    stateApplyCount++;
    final rate:Int = Std.isOfType(state, play.PlayState) ? ClientPrefs.framerate : ClientPrefs.menuFramerate;
    lastMenuFramerate = ClientPrefs.menuFramerate;
    return rate;
  }

  /**
   * Records a focus-lost framerate sync.
   *
   * @param fps Target unfocused framerate.
   * @return Clamped target framerate.
   */
  public static function applyFocusLost(fps:Int):Int
  {
    lastFocusLostFramerate = fps < 1 ? 1 : fps;
    return lastFocusLostFramerate;
  }

  /** Resets recorded framerate counters between test cases. */
  public static function reset():Void
  {
    stateApplyCount = 0;
    lastMenuFramerate = 60;
    lastFocusLostFramerate = 60;
  }
}
