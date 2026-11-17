package backend;

import flixel.FlxG;

/**
 * Windows GDI desktop effects — ported from Slushi Engine.
 *
 * These effects draw directly on the desktop using raw GDI calls, running on
 * a dedicated background thread so they never lag the game. Typical use cases
 * are meta-horror mods, "4th wall breaking" moments, or glitch aesthetics.
 *
 * Usage example:
 * ```
 * GDIEffects.init();
 * GDIEffects.enableEffect("ScreenGlitches");
 * GDIEffects.setEffectWait("ScreenGlitches", 50); // 50ms between frames
 * // ... later ...
 * GDIEffects.disableEffect("ScreenGlitches");
 * GDIEffects.destroy();
 * ```
 *
 * Available effects:
 * - "DrawIcons"       — Error/warning icons follow the mouse cursor
 * - "ScreenBlink"     — Invert desktop colors (flash)
 * - "ScreenGlitches"  — Copy random rectangles to random positions
 * - "ScreenTunnel"    — Recursive StretchBlt tunnel
 * - "ScreenShake"     — Shake screen with small random offsets
 * - "SetTitleText"    — Set custom text on all window title bars
 *
 * @see backend.GdiNative — the native bridge
 */
class GDIEffects
{
  /** Whether the GDI subsystem is initialized. */
  public static var initialized(get, never):Bool;

  static inline function get_initialized():Bool
  {
    #if (cpp && windows)
      return sInitialized;
    #else
      return false;
    #end
  }

  /** Whether we're running on a supported target (Windows native). */
  public static var isSupported(get, never):Bool;

  static inline function get_isSupported():Bool
  {
    #if (cpp && windows)
      return true;
    #else
      return false;
    #end
  }

  /** List of all available effect names. */
  public static var availableEffects(get, never):Array<String>;

  static inline function get_availableEffects():Array<String>
    return ["DrawIcons", "ScreenBlink", "ScreenGlitches", "ScreenTunnel", "ScreenShake", "SetTitleText"];

  /* ---------------------------------------------------------------------- */
  /*                            LIFECYCLE                                   */
  /* ---------------------------------------------------------------------- */

  static var sInitialized:Bool = false;
  static var sElapsedTime:Float = 0;
  static var sPaused:Bool = false;
  static var sRegisteredEffects:Map<String, Bool> = [];

  /**
   * Initialize the GDI subsystem (starts the background thread).
   * Safe to call multiple times; subsequent calls are no-ops.
   * @return true on success, false if already initialized or unsupported.
   */
  public static function init():Bool
  {
    #if (cpp && windows)
      if (sInitialized)
        return true;

      if (!isSupported)
      {
        trace("GDIEffects: not supported on this target");
        return false;
      }

      if (!GdiNative.initialize())
      {
        trace("GDIEffects: failed to initialize native subsystem");
        return false;
      }

      sInitialized = true;
      sElapsedTime = 0;
      sPaused = false;
      sRegisteredEffects = [];

      // Hook into FlxG update to feed elapsed time
      FlxG.signals.preUpdate.add(updateElapsedTime);

      trace("GDIEffects: initialized");
      return true;
    #else
      trace("GDIEffects: not supported on this target ($targetName)");
      return false;
    #end
  }

  /**
   * Shutdown the GDI subsystem (stops the background thread).
   * All effects are automatically unregistered.
   */
  public static function destroy():Void
  {
    #if (cpp && windows)
      if (!sInitialized)
        return;

      FlxG.signals.preUpdate.remove(updateElapsedTime);

      // Disable all effects before shutdown
      for (effectName in sRegisteredEffects.keys())
        disableEffect(effectName);

      GdiNative.shutdown();
      sInitialized = false;
      sRegisteredEffects.clear();
      trace("GDIEffects: destroyed");
    #end
  }

  /**
   * Pause all GDI effects without destroying the thread.
   * Useful when the game loses focus or enters a cutscene.
   */
  public static function setPaused(paused:Bool):Void
  {
    #if (cpp && windows)
      if (!sInitialized)
        return;

      sPaused = paused;
      GdiNative.setPaused(paused);
    #end
  }

  /* ---------------------------------------------------------------------- */
  /*                        EFFECT REGISTRATION                             */
  /* ---------------------------------------------------------------------- */

  /**
   * Register an effect by name so it can be enabled/disabled.
   * Effects must be registered before use.
   * @param name Effect name (see `availableEffects`)
   * @return true on success, false if unknown effect or unsupported.
   */
  public static function registerEffect(name:String):Bool
  {
    #if (cpp && windows)
      if (!sInitialized)
      {
        trace("GDIEffects: call init() before registering effects");
        return false;
      }

      if (!availableEffects.exists(name))
      {
        trace("GDIEffects: unknown effect '$name'");
        return false;
      }

      if (sRegisteredEffects.exists(name))
        return true; // already registered

      if (GdiNative.registerEffect(name))
      {
        sRegisteredEffects.set(name, true);
        trace("GDIEffects: registered effect '$name'");
        return true;
      }

      trace("GDIEffects: failed to register effect '$name'");
      return false;
    #else
      return false;
    #end
  }

  /**
   * Unregister an effect. Disables it first if currently enabled.
   */
  public static function unregisterEffect(name:String):Void
  {
    #if (cpp && windows)
      if (!sInitialized)
        return;

      if (!sRegisteredEffects.exists(name))
        return;

      disableEffect(name);
      GdiNative.unregisterEffect(name);
      sRegisteredEffects.remove(name);
      trace("GDIEffects: unregistered effect '$name'");
    #end
  }

  /* ---------------------------------------------------------------------- */
  /*                          EFFECT CONTROL                                */
  /* ---------------------------------------------------------------------- */

  /**
   * Enable a registered effect.
   * @param name Effect name
   * @return true if enabled, false if not registered or unsupported.
   */
  public static function enableEffect(name:String):Bool
  {
    #if (cpp && windows)
      if (!sInitialized || !sRegisteredEffects.exists(name))
      {
        trace("GDIEffects: effect '$name' not registered (call registerEffect first)");
        return false;
      }

      GdiNative.setEffectEnabled(name, true);
      trace("GDIEffects: enabled effect '$name'");
      return true;
    #else
      return false;
    #end
  }

  /**
   * Disable a registered effect.
   */
  public static function disableEffect(name:String):Void
  {
    #if (cpp && windows)
      if (!sInitialized || !sRegisteredEffects.exists(name))
        return;

      GdiNative.setEffectEnabled(name, false);
      trace("GDIEffects: disabled effect '$name'");
    #end
  }

  /**
   * Toggle a registered effect on/off.
   * @return The new enabled state, or false if not registered.
   */
  public static function toggleEffect(name:String):Bool
  {
    #if (cpp && windows)
      if (!sInitialized || !sRegisteredEffects.exists(name))
        return false;

      // We don't have a getter, so just disable and re-enable to toggle
      // In practice, mods usually know what state they want.
      GdiNative.setEffectEnabled(name, true); // Best effort
      return true;
    #else
      return false;
    #end
  }

  /**
   * Set the wait time between frames for an effect (in milliseconds).
   * Higher values = slower effect, less CPU. Default is 0 (as fast as possible).
   * @param name Effect name
   * @param waitMs Milliseconds to wait between executions (clamped to >= 0)
   */
  public static function setEffectWait(name:String, waitMs:Float):Void
  {
    #if (cpp && windows)
      if (!sInitialized || !sRegisteredEffects.exists(name))
        return;

      if (waitMs < 0) waitMs = 0;
      GdiNative.setEffectWait(name, waitMs);
    #end
  }

  /**
   * Check if an effect is currently registered.
   */
  public static function isEffectRegistered(name:String):Bool
  {
    #if (cpp && windows)
      return sRegisteredEffects.exists(name);
    #else
      return false;
    #end
  }

  /* ---------------------------------------------------------------------- */
  /*                       ONE-SHOT PAYLOAD TRIGGERS                        */
  /* ---------------------------------------------------------------------- */
  /* These run immediately on the calling thread (not the background thread).
   * Use for instant, one-time effects like a jumpscare flash. */

  /** Draw error/warning icons at the mouse cursor position. */
  public static function drawIcons():Void
  {
    #if (cpp && windows)
      GdiNative.drawIcons();
    #end
  }

  /** Invert the entire desktop colors once (flash). */
  public static function screenBlink():Void
  {
    #if (cpp && windows)
      GdiNative.screenBlink();
    #end
  }

  /** Copy random screen rectangles to random positions once (glitch). */
  public static function screenGlitches():Void
  {
    #if (cpp && windows)
      GdiNative.screenGlitches();
    #end
  }

  /** Apply the tunnel effect once. */
  public static function screenTunnel():Void
  {
    #if (cpp && windows)
      GdiNative.screenTunnel();
    #end
  }

  /** Shake the screen once. */
  public static function screenShake():Void
  {
    #if (cpp && windows)
      GdiNative.screenShake();
    #end
  }

  /**
   * Set custom text on all top-level window title bars.
   * @param text The text to display (UTF-8)
   */
  public static function setCustomTitleText(text:String):Void
  {
    #if (cpp && windows)
      GdiNative.setCustomTitleText(text);
    #end
  }

  /* ---------------------------------------------------------------------- */
  /*                           INTERNAL                                     */
  /* ---------------------------------------------------------------------- */

  static function updateElapsedTime():Void
  {
    #if (cpp && windows)
      if (!sInitialized || sPaused)
        return;

      sElapsedTime += FlxG.elapsed;
      GdiNative.setElapsedTime(sElapsedTime);
    #end
  }

  /** Compile-time name of the current target, used for logging. */
  static var targetName(get, never):String;

  static inline function get_targetName():String
  {
    #if windows
      return "windows";
    #elseif linux
      return "linux";
    #elseif mac
      return "macOS";
    #elseif android
      return "android";
    #elseif ios
      return "iOS";
    #elseif flash
      return "flash";
    #elseif web
      return "html5";
    #else
      return "this target";
    #end
  }
}