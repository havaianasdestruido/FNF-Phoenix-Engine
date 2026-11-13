package backend;

import flixel.FlxG;

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
