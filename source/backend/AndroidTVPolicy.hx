package backend;

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
