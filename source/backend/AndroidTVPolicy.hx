package backend;

/** Mutable state of the "is there actually a TV controller here?" probe. */
typedef ControllerProbe = {
  /** Seconds the probe has been listening for controller input. */
  var elapsed:Float;
  /** A remote / D-pad / gamepad press arrived inside the window. */
  var sawInput:Bool;
  /** The probe already finished (confirmed or expired); stop counting. */
  var settled:Bool;
}

/** Verdict of one probe frame. */
typedef ControllerProbeStep = {
  /** Still inside the window and nothing has arrived yet. */
  var listening:Bool;
  /** The window closed without any controller input: turn the option off. */
  var disable:Bool;
}

/**
 * Pure policy helpers for Android TV / touchless remote navigation.
 *
 * Kept free of OpenFL and Flixel dependencies so Haxe unit specs can verify
 * the behavior directly under `--interp`.
 */
class AndroidTVPolicy
{
  /**
   * Auto-enables touchless TV navigation on first launch whenever Android
   * identifies as a TV/Leanback device or reports no touchscreen hardware.
   */
  public static inline function shouldAutoEnable(isTV:Bool, hasTouchscreen:Bool):Bool
  {
    return isTV || !hasTouchscreen;
  }

  /**
   * True when menus and HUD should prioritize D-pad / gamepad navigation
   * and suppress desktop hover cursors / on-screen touch overlays.
   */
  public static inline function shouldUseTouchlessUI(tvNavEnabled:Bool):Bool
  {
    return tvNavEnabled == true;
  }

  /**
   * Touch controls are shown only when touchless TV navigation is inactive
   * and the user has a visible touch-control opacity configured.
   */
  public static inline function shouldShowTouchControls(tvNavEnabled:Bool, mobileAlpha:Float):Bool
  {
    return !shouldUseTouchlessUI(tvNavEnabled) && mobileAlpha >= 0.1;
  }

  /**
   * Keeps the floating mouse pointer hidden in touchless TV mode so remote
   * focus highlights remain clean without a stranded cursor on screen.
   */
  public static inline function shouldShowMouseCursor(tvNavEnabled:Bool):Bool
  {
    return !shouldUseTouchlessUI(tvNavEnabled);
  }

  /**
   * Seconds the TV controller probe listens for input.
   *
   * TV navigation hides the on-screen touch buttons and the mouse cursor, so an
   * Android device running that mode without a remote/gamepad that actually
   * reports input ends up with no usable pointer at all. The option therefore
   * only stays enabled when the device proves it has a controller: during the
   * first five seconds after it turns on, any remote/D-pad/gamepad press keeps
   * it on, and a window that closes with no input at all turns it back off.
   */
  public static inline var CONTROLLER_PROBE_SECONDS:Float = 5.0;

  /**
   * Longest frame the probe accepts as progress.
   *
   * Loading stalls and background/foreground wake-ups produce one huge
   * `FlxG.elapsed`, and the player cannot press anything while the game is
   * frozen; clamping keeps a stall from eating the whole window at once.
   */
  public static inline var CONTROLLER_PROBE_MAX_FRAME_SECONDS:Float = 0.25;

  /** A fresh probe, ready to listen for `CONTROLLER_PROBE_SECONDS`. */
  public static function newControllerProbe():ControllerProbe
  {
    return {elapsed: 0.0, sawInput: false, settled: false};
  }

  /** Re-arms a probe (the option was turned on again after being off). */
  public static function resetControllerProbe(probe:ControllerProbe):Void
  {
    if (probe == null)
      return;
    probe.elapsed = 0.0;
    probe.sawInput = false;
    probe.settled = false;
  }

  /** Seconds left in the window; `0` once it closed or was confirmed. */
  public static function controllerProbeRemaining(probe:ControllerProbe):Float
  {
    if (probe == null || probe.settled || probe.sawInput)
      return 0.0;
    final left:Float = CONTROLLER_PROBE_SECONDS - probe.elapsed;
    return left > 0.0 ? left : 0.0;
  }

  /**
   * Advances the probe by one frame.
   *
   * @param probe State from `newControllerProbe()`.
   * @param delta Seconds elapsed this frame (negative values are ignored, long
   *              frames are clamped to `CONTROLLER_PROBE_MAX_FRAME_SECONDS`).
   * @param controllerInput A remote/D-pad/gamepad press arrived this frame.
   * @return `listening` while the window is still open, `disable` on the frame
   *         the window closes without any input.
   */
  public static function stepControllerProbe(probe:ControllerProbe, delta:Float, controllerInput:Bool):ControllerProbeStep
  {
    if (probe == null || probe.settled)
      return {listening: false, disable: false};

    if (controllerInput)
    {
      // A real controller answered: keep TV navigation on for good.
      probe.sawInput = true;
      probe.settled = true;
      probe.elapsed = CONTROLLER_PROBE_SECONDS;
      return {listening: false, disable: false};
    }

    final step:Float = (delta > 0.0) ? (delta < CONTROLLER_PROBE_MAX_FRAME_SECONDS ? delta : CONTROLLER_PROBE_MAX_FRAME_SECONDS) : 0.0;
    probe.elapsed += step;
    if (probe.elapsed < CONTROLLER_PROBE_SECONDS)
      return {listening: true, disable: false};

    // Nothing answered inside the window: this device has no TV controller.
    probe.elapsed = CONTROLLER_PROBE_SECONDS;
    probe.settled = true;
    return {listening: false, disable: true};
  }

  /**
   * Only background the Android activity on Back when sitting at the root
   * TitleState with no active modal prompt/substate or active transition.
   */
  public static inline function shouldBackgroundOnTitleBack(isAndroid:Bool, subStateOpen:Bool, transitioning:Bool, backPressed:Bool):Bool
  {
    return isAndroid && !subStateOpen && !transitioning && backPressed;
  }

  /**
   * Toggles binary confirm/cancel focus (0 = Yes/Accept, 1 = Cancel/No) when
   * navigating left or right with a D-pad or remote.
   */
  public static inline function selectPromptChoice(current:Int, delta:Int):Int
  {
    if (delta == 0)
      return current == 0 ? 0 : 1;
    return current == 0 ? 1 : 0;
  }
}
