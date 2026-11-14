package backend;

import flixel.FlxG;
import StringTools;

/**
 * Three-way window display mode: **Windowed**, **Borderless** and
 * **Fullscreen** (Graphics options, desktop builds only).
 *
 * The engine historically started windowed every time and only exposed
 * exclusive fullscreen through the F11 hotkey, so the choice was never
 * remembered. This module owns the mode end to end:
 *
 * - `ClientPrefs.windowMode` holds the selected mode and is written to the
 *   save file exactly like the other graphics preferences (desktop-only, see
 *   `backend.PlatformSupport`);
 * - `apply()` pushes the mode to the native window through `FlxG.fullscreen`
 *   (exclusive fullscreen) and `lime.ui.Window.borderless` (borderless);
 * - the F11 hotkey (`backend.FunkinGame`) and the option row both go through
 *   `set()` / `toggleFullscreen()`, so the mode stays in sync and is persisted
 *   even when the player toggles it with the keyboard.
 *
 * **Borderless** keeps the game out of exclusive fullscreen while dropping the
 * window frame, which avoids the cursor-tearing / monitor-switching artifacts
 * exclusive fullscreen can cause on some drivers. It is still a windowed
 * surface, so `backend.TransparentWindow` keeps working in it.
 *
 * Every setter is a safe no-op on targets without a native window: they never
 * throw and return `false`.
 */
class WindowMode
{
  /** Normal bordered window. */
  public static final WINDOWED:String = 'Windowed';
  /** Frameless window that fills the screen without exclusive fullscreen. */
  public static final BORDERLESS:String = 'Borderless';
  /** Exclusive fullscreen (`FlxG.fullscreen`). */
  public static final FULLSCREEN:String = 'Fullscreen';

  /** The three modes in display order; also the option row's value list. */
  public static final MODES:Array<String> = [WINDOWED, BORDERLESS, FULLSCREEN];

  /**
   * Accepted spellings for each mode. Matching is case-insensitive and
   * whitespace-trimmed; anything unknown falls back to {@link WINDOWED} so a
   * hand-edited save or a mod that passes a typo cannot leave the game in an
   * undefined state.
   */
  static final ALIASES:Map<String, String> = [
    'window' => WINDOWED,
    'windowed' => WINDOWED,
    'normal' => WINDOWED,
    'borderless' => BORDERLESS,
    'fullscreen' => FULLSCREEN,
    'full' => FULLSCREEN,
    'exclusive' => FULLSCREEN
  ];

  /** The mode the game was in before F11 forced fullscreen, for restoring it. */
  static var preFullscreen:String = WINDOWED;

  /** Normalize any stored/mod-provided value to a known mode. */
  public static function normalize(mode:Dynamic):String
  {
    if (mode == null) return WINDOWED;

    final text:String = StringTools.trim(Std.string(mode)).toLowerCase();
    final known:String = ALIASES.get(text);
    return known != null ? known : WINDOWED;
  }

  /** The normalized mode currently selected in {@link ClientPrefs.windowMode}. */
  public static function current():String
    return normalize(ClientPrefs.windowMode);

  /** `true` when the selected mode is exclusive fullscreen. */
  public static function isFullscreen():Bool
    return current() == FULLSCREEN;

  /** `true` when the selected mode is borderless. */
  public static function isBorderless():Bool
    return current() == BORDERLESS;

  /**
   * `true` when the native window is actually in exclusive fullscreen right
   * now. Unlike {@link isFullscreen} this reads the live window, so it also
   * catches a fullscreen state that was set outside this module.
   */
  public static function isFullscreenNow():Bool
  {
    #if !flash
    final window = getWindow();
    if (window != null) return window.fullscreen == true;
    #endif
    return FlxG.fullscreen;
  }

  /**
   * Apply a mode to the live window without touching the preference.
   *
   * @param mode  One of {@link MODES} (or any accepted alias); `null` uses the
   *              current preference.
   * @return `true` when the request was pushed to the window.
   */
  public static function apply(?mode:Dynamic):Bool
    return applyMode(normalize(mode));

  /**
   * Select a mode, apply it and (optionally) persist it.
   *
   * @param mode  One of {@link MODES} (or any accepted alias).
   * @param save  When `true`, flush the preference to the save file now.
   * @return `true` when the mode was applied.
   */
  public static function set(mode:Dynamic, save:Bool = true):Bool
  {
    final target:String = normalize(mode);
    ClientPrefs.windowMode = target;
    final applied:Bool = applyMode(target);
    if (save) ClientPrefs.saveSettings();
    return applied;
  }

  /**
   * F11's fullscreen toggle. Entering fullscreen remembers the current
   * (non-fullscreen) mode so the toggle returns to it — borderless players
   * keep their borderless window, windowed players keep their bordered one.
   * The choice is persisted, so restarting honours it.
   *
   * @return `true` when the game ended up fullscreen.
   */
  public static function toggleFullscreen():Bool
  {
    if (isFullscreenNow())
    {
      final restore:String = (preFullscreen == FULLSCREEN) ? WINDOWED : preFullscreen;
      set(restore);
      return false;
    }

    preFullscreen = current();
    set(FULLSCREEN);
    return true;
  }

  /**
   * Leave exclusive fullscreen, restoring the last non-fullscreen mode and
   * persisting it. Used by features that only make sense on a windowed game
   * (e.g. `backend.TransparentWindow`); returns `false` when the game was not
   * fullscreen to begin with.
   *
   * @return `true` when fullscreen was left.
   */
  public static function leaveFullscreen():Bool
  {
    if (!isFullscreenNow()) return false;

    final restore:String = (preFullscreen == FULLSCREEN) ? WINDOWED : preFullscreen;
    set(restore);
    return true;
  }

  /**
   * Resize the game window and the logical viewport (the same path the
   * resolution option uses). Desktop native targets only.
   *
   * @param width  New width in pixels, must be positive.
   * @param height New height in pixels, must be positive.
   * @return `true` when the resize was applied.
   */
  public static function resize(width:Int, height:Int):Bool
  {
    #if (desktop && !air)
    if (width <= 0 || height <= 0) return false;
    CoolUtil.resetResScale(width, height);
    FlxG.resizeWindow(width, height);
    return true;
    #else
    return false;
    #end
  }

  /** Current logical game size as `[width, height]`. */
  public static function getWindowSize():Array<Int>
    return [FlxG.width, FlxG.height];

  /**
   * Push one concrete mode to the native window. Desktop native targets only;
   * every other build is a safe no-op (the option and the preference are
   * desktop-only anyway, see `backend.PlatformSupport`).
   */
  static function applyMode(target:String):Bool
  {
    #if desktop
    if (target == FULLSCREEN)
    {
      FlxG.fullscreen = true;
      return true;
    }

    // Windowed / Borderless: leave exclusive fullscreen first so setting the
    // frame does not fight the fullscreen state, then pick the frame.
    FlxG.fullscreen = false;
    final window = getWindow();
    if (window != null) window.borderless = (target == BORDERLESS);
    return true;
    #else
    return false;
    #end
  }

  /**
   * The Lime window, or `null` when the target has none (Flash).
   *
   * Typed as `Dynamic` on purpose: `lime.ui.Window` is only reachable on the
   * targets that actually have a native window.
   */
  static function getWindow():Dynamic
  {
    #if !flash
    if (FlxG.stage != null && FlxG.stage.window != null) return FlxG.stage.window;
    final app:lime.app.Application = lime.app.Application.current;
    return (app != null) ? app.window : null;
    #else
    return null;
    #end
  }
}
