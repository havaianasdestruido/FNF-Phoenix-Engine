package backend;

import flixel.FlxG;
import flixel.input.keyboard.FlxKey;
import flixel.input.gamepad.FlxGamepadInputID;

import backend.AndroidTVPolicy.ControllerProbe;
import backend.AndroidTVPolicy.ControllerProbeStep;

/**
 * Runtime glue for Android TV / touchless navigation: caches hardware TV
 * detection and latches synthetic Back/Menu navigation signals across one full
 * Flixel update frame.
 */
class TouchlessUI
{
  static var initialized:Bool = false;
  static var hardwareChecked:Bool = false;
  static var hardwareTouchless:Bool = false;

  static var pendingBack:Bool = false;
  static var pendingMenu:Bool = false;
  static var backThisFrame:Bool = false;
  static var menuThisFrame:Bool = false;

  /** Keys a TV remote / D-pad reports (openfl Keyboard patch: SELECT -> ENTER). */
  static var tvNavKeys:Array<FlxKey> = [FlxKey.UP, FlxKey.DOWN, FlxKey.LEFT, FlxKey.RIGHT, FlxKey.ENTER, FlxKey.SPACE, FlxKey.ESCAPE,
    FlxKey.BACKSPACE, FlxKey.MENU, FlxKey.TAB];

  /** Pad buttons a remote or controller reports while navigating those same menus. */
  static var tvNavButtons:Array<FlxGamepadInputID> = [FlxGamepadInputID.A, FlxGamepadInputID.B, FlxGamepadInputID.X, FlxGamepadInputID.Y,
    FlxGamepadInputID.DPAD_UP, FlxGamepadInputID.DPAD_DOWN, FlxGamepadInputID.DPAD_LEFT, FlxGamepadInputID.DPAD_RIGHT,
    FlxGamepadInputID.LEFT_STICK_DIGITAL_UP, FlxGamepadInputID.LEFT_STICK_DIGITAL_DOWN, FlxGamepadInputID.LEFT_STICK_DIGITAL_LEFT,
    FlxGamepadInputID.LEFT_STICK_DIGITAL_RIGHT, FlxGamepadInputID.START, FlxGamepadInputID.BACK, FlxGamepadInputID.LEFT_SHOULDER,
    FlxGamepadInputID.RIGHT_SHOULDER];

  /** Controller probe armed for the current stretch of TV navigation being on. */
  static var controllerProbe:ControllerProbe = AndroidTVPolicy.newControllerProbe();
  static var probeWatching:Bool = false;

  /** Subscribes to AndroidBridge navigation signals and Flixel frame ticks. */
  public static function init():Void
  {
    #if android
    if (initialized)
      return;
    initialized = true;

    android.platform.AndroidBridge.onNavAction.add(function(action:String)
    {
      switch (action)
      {
        case 'back':
          pendingBack = true;
        case 'menu':
          pendingMenu = true;
      }
    });
    FlxG.signals.preUpdate.add(advanceFrame);
    #end
  }

  static function advanceFrame():Void
  {
    backThisFrame = pendingBack;
    pendingBack = false;
    menuThisFrame = pendingMenu;
    pendingMenu = false;
    updateControllerProbe();
  }

  /**
   * Keeps Android TV navigation only on devices that prove they have a TV
   * controller.
   *
   * The option hides the touch overlay and the mouse cursor, so leaving it on
   * for a device whose remote/gamepad never reports anything strands the player
   * without a pointer. Every time the mode turns on it listens for
   * `AndroidTVPolicy.CONTROLLER_PROBE_SECONDS` seconds: any remote/D-pad/gamepad
   * press keeps it on, and a window that closes with no input turns the option
   * back off (and saves that, so the next launch does not repeat it).
   */
  static function updateControllerProbe():Void
  {
    #if android
    if (!isActive())
    {
      // Off (or never enabled): re-arm so the next enable gets a full window.
      probeWatching = false;
      return;
    }

    if (!probeWatching)
    {
      probeWatching = true;
      AndroidTVPolicy.resetControllerProbe(controllerProbe);
    }

    if (controllerProbe.settled)
      return;

    final step:ControllerProbeStep = AndroidTVPolicy.stepControllerProbe(controllerProbe, FlxG.elapsed, hasControllerInput());
    if (step.disable)
      disableTVNavigation();
    #end
  }

  /** True when a remote, D-pad or gamepad reported input on this frame. */
  static function hasControllerInput():Bool
  {
    #if android
    // Back/Menu arrive as synthetic navigation signals instead of key presses.
    if (backThisFrame || menuThisFrame)
      return true;

    // A TV remote reaches the game as D-pad/SELECT/MENU key codes.
    if (FlxG.keys != null && FlxG.keys.anyJustPressed(tvNavKeys))
      return true;

    if (FlxG.gamepads == null)
      return false;
    for (button in tvNavButtons)
      if (FlxG.gamepads.anyJustPressed(button))
        return true;
    #end

    return false;
  }

  /**
   * Turns Android TV navigation off after the probe window closed with no
   * controller input, and persists it so the setting matches what the player
   * sees while the game runs.
   */
  static function disableTVNavigation():Void
  {
    #if android
    probeWatching = false;
    if (!ClientPrefs.androidTVNavigation)
      return;

    ClientPrefs.androidTVNavigation = false;

    // Same targeted write as the first-launch auto-enable in `ClientPrefs.loadPrefs()`.
    // A bypassed (recovery) boot leaves the file alone, like `saveSettings()` does.
    if (FlxG.save != null)
    {
      FlxG.save.data.androidTVNavigation = false;
      if (!RecoveryBoot.freshPrefs)
        FlxG.save.flush();
    }

    // A touchscreen device gets its pointer back; a touchless box stays cursor-free.
    syncMouseCursor(!isHardwareTouchless());
    VLog.log('TV', 'Android TV navigation auto-disabled: no remote/controller input in the first '
      + AndroidTVPolicy.CONTROLLER_PROBE_SECONDS + 's.');
    trace('Android TV Navigation disabled: no TV controller input in the first ' + AndroidTVPolicy.CONTROLLER_PROBE_SECONDS + ' seconds.');
    #end
  }

  /** True when running on Android TV / Leanback or touchless hardware. */
  public static function isHardwareTouchless():Bool
  {
    #if android
    if (!hardwareChecked)
    {
      hardwareChecked = true;
      hardwareTouchless = AndroidTVPolicy.shouldAutoEnable(
        android.platform.AndroidSystem.isAndroidTV(),
        android.platform.AndroidSystem.hasTouchscreen()
      );
    }
    return hardwareTouchless;
    #else
    return false;
    #end
  }

  /** True when TV/remote touchless navigation UX is active. */
  public static inline function isActive():Bool
  {
    return AndroidTVPolicy.shouldUseTouchlessUI(ClientPrefs.androidTVNavigation);
  }

  /** True for the duration of the frame when Android reported Back/gesture Back. */
  public static inline function isBackPressed():Bool
  {
    return backThisFrame;
  }

  /** True for the duration of the frame when Android reported Menu (`KEYCODE_MENU`). */
  public static inline function isMenuPressed():Bool
  {
    return menuThisFrame;
  }

  /** Updates mouse pointer visibility according to touchless TV policy. */
  public static inline function syncMouseCursor(preferVisible:Bool = true):Void
  {
    #if FLX_MOUSE
    if (FlxG.mouse != null)
      FlxG.mouse.visible = preferVisible && AndroidTVPolicy.shouldShowMouseCursor(isActive());
    #end
  }
}
