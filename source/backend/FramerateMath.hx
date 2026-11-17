package backend;

/**
 * Renderer-free rules behind the **Menu Framerate** and **Focus Lost
 * Framerate** preferences (Options -> Graphics).
 *
 * Kept Flixel-free so `tests/haxe/run-menu-framerate.sh` can execute it in
 * the Haxe interpreter. The stateful half (writing `FlxG`'s rates and the
 * frame profiler) lives in `backend.FramerateController`.
 *
 * ### Why two rates
 *
 * `ClientPrefs.framerate` is the gameplay rate and can be set up to 1000
 * (10000 with Uncapped FPS). Menus used to inherit it, so an idle main menu
 * rendered a thousand frames a second and drained the battery. Menus and
 * editors now run at `ClientPrefs.menuFramerate` (default 60); only
 * `play.PlayState` keeps `framerate`.
 */
class FramerateMath
{
  /** Smallest rate the engine will run at. */
  public static inline var MIN_FPS:Int = 1;

  /** Cap while Uncapped FPS is off, matching the Options -> Graphics row. */
  public static inline var DEFAULT_CAP:Int = 1000;

  /** Cap while Uncapped FPS is on, matching the Options -> Graphics row. */
  public static inline var UNCAPPED_CAP:Int = 10000;

  /** The cap the rows and the controller clamp to. */
  public static inline function cap(uncappedFps:Bool):Int
    return uncappedFps ? UNCAPPED_CAP : DEFAULT_CAP;

  /**
   * Clamps any int into `[MIN_FPS, cap(uncappedFps)]`.
   *
   * Hand-edited save files can hold zero, negatives or absurd values; the
   * options row only steps within the band, the save file does not have to.
   */
  public static function clamp(fps:Int, uncappedFps:Bool):Int
  {
    if (fps < MIN_FPS) return MIN_FPS;
    final max:Int = cap(uncappedFps);
    return fps > max ? max : fps;
  }

  /**
   * Which rate a freshly created state should run at (the policy behind
   * `backend.FramerateController.applyForState`): gameplay keeps the
   * "Framerate" option, every other state (menus, editors, loading screens)
   * runs at "Menu Framerate".
   */
  public static inline function stateRate(isGameplayState:Bool, framerate:Int, menuFramerate:Int):Int
    return isGameplayState ? framerate : menuFramerate;
}
