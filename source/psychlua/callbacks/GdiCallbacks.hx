package psychlua.callbacks;

import backend.GDIEffects;
import psychlua.FunkinLua;
import psychlua.LuaUtils;
import flixel.FlxG;
import flixel.util.FlxColor;

/**
 * Windows GDI desktop effects exposed to Lua/Python/HScript.
 *
 * These are visual effects that draw directly on the desktop using raw GDI calls.
 * They run on a dedicated background thread so they never lag the game.
 * Typical use cases: meta-horror mods, "4th wall breaking" moments, glitch aesthetics.
 *
 * Available effects (register first, then enable):
 * - "DrawIcons"       — Error/warning icons follow the mouse cursor
 * - "ScreenBlink"     — Invert desktop colors (flash)
 * - "ScreenGlitches"  — Copy random rectangles to random positions
 * - "ScreenTunnel"    — Recursive StretchBlt tunnel
 * - "ScreenShake"     — Shake screen with small random offsets
 * - "SetTitleText"    — Set custom text on all window title bars
 *
 * One-shot triggers (run immediately, no registration needed):
 * - gdiDrawIcons()
 * - gdiScreenBlink()
 * - gdiScreenGlitches()
 * - gdiScreenTunnel()
 * - gdiScreenShake()
 * - gdiSetTitleText(text)
 *
 * All functions compile on all targets but only take effect on Windows native builds.
 * On other targets they are safe no-ops that log a warning.
 */
class GdiCallbacks
{
  public static function register(funk:FunkinLua):Void
  {
    @:privateAccess
    {
      // ------------------------------------------------------------------
      // Lifecycle
      // ------------------------------------------------------------------
      FunkinLua.registerFunction("gdiInit", function():Bool
      {
        #if (cpp && windows)
        return GDIEffects.init();
        #else
        gdiWarning(funk, 'gdiInit');
        return false;
        #end
      });

      FunkinLua.registerFunction("gdiDestroy", function()
      {
        #if (cpp && windows)
        GDIEffects.destroy();
        #else
        gdiWarning(funk, 'gdiDestroy');
        #end
      });

      FunkinLua.registerFunction("gdiSetPaused", function(paused:Bool)
      {
        #if (cpp && windows)
        GDIEffects.setPaused(paused);
        #else
        gdiWarning(funk, 'gdiSetPaused');
        #end
      });

      FunkinLua.registerFunction("gdiIsInitialized", function():Bool
      {
        #if (cpp && windows)
        return GDIEffects.initialized;
        #else
        return false;
        #end
      });

      // ------------------------------------------------------------------
      // Effect registration & control
      // ------------------------------------------------------------------
      FunkinLua.registerFunction("gdiRegisterEffect", function(name:String):Bool
      {
        #if (cpp && windows)
        return GDIEffects.registerEffect(name);
        #else
        gdiWarning(funk, 'gdiRegisterEffect');
        return false;
        #end
      });

      FunkinLua.registerFunction("gdiUnregisterEffect", function(name:String)
      {
        #if (cpp && windows)
        GDIEffects.unregisterEffect(name);
        #else
        gdiWarning(funk, 'gdiUnregisterEffect');
        #end
      });

      FunkinLua.registerFunction("gdiEnableEffect", function(name:String):Bool
      {
        #if (cpp && windows)
        return GDIEffects.enableEffect(name);
        #else
        gdiWarning(funk, 'gdiEnableEffect');
        return false;
        #end
      });

      FunkinLua.registerFunction("gdiDisableEffect", function(name:String)
      {
        #if (cpp && windows)
        GDIEffects.disableEffect(name);
        #else
        gdiWarning(funk, 'gdiDisableEffect');
        #end
      });

      FunkinLua.registerFunction("gdiSetEffectWait", function(name:String, waitMs:Float)
      {
        #if (cpp && windows)
        GDIEffects.setEffectWait(name, waitMs);
        #else
        gdiWarning(funk, 'gdiSetEffectWait');
        #end
      });

      FunkinLua.registerFunction("gdiIsEffectRegistered", function(name:String):Bool
      {
        #if (cpp && windows)
        return GDIEffects.isEffectRegistered(name);
        #else
        return false;
        #end
      });

      FunkinLua.registerFunction("gdiGetAvailableEffects", function():Array<String>
      {
        #if (cpp && windows)
        return GDIEffects.availableEffects;
        #else
        return [];
        #end
      });

      // ------------------------------------------------------------------
      // One-shot payload triggers (run immediately on calling thread)
      // ------------------------------------------------------------------
      FunkinLua.registerFunction("gdiDrawIcons", function()
      {
        #if (cpp && windows)
        GDIEffects.drawIcons();
        #else
        gdiWarning(funk, 'gdiDrawIcons');
        #end
      });

      FunkinLua.registerFunction("gdiScreenBlink", function()
      {
        #if (cpp && windows)
        GDIEffects.screenBlink();
        #else
        gdiWarning(funk, 'gdiScreenBlink');
        #end
      });

      FunkinLua.registerFunction("gdiScreenGlitches", function()
      {
        #if (cpp && windows)
        GDIEffects.screenGlitches();
        #else
        gdiWarning(funk, 'gdiScreenGlitches');
        #end
      });

      FunkinLua.registerFunction("gdiScreenTunnel", function()
      {
        #if (cpp && windows)
        GDIEffects.screenTunnel();
        #else
        gdiWarning(funk, 'gdiScreenTunnel');
        #end
      });

      FunkinLua.registerFunction("gdiScreenShake", function()
      {
        #if (cpp && windows)
        GDIEffects.screenShake();
        #else
        gdiWarning(funk, 'gdiScreenShake');
        #end
      });

      FunkinLua.registerFunction("gdiSetTitleText", function(text:String)
      {
        #if (cpp && windows)
        GDIEffects.setCustomTitleText(text);
        #else
        gdiWarning(funk, 'gdiSetTitleText');
        #end
      });
    }
  }

  /**
   * Seed the same API into an HScript interpreter's scope.
   * HScript inherits the shared Lua registry when a Lua script is loaded,
   * but a mod that ships only `.hx` scripts has no Lua parent, so this seeds
   * the API directly.
   */
  public static function seedHScript(interp:Dynamic):Void
  {
    registerApi(function(name:String, func:Dynamic)
    {
      interp.variables.set(name, func);
    });
  }

  private static function registerApi(register:(String, Dynamic)->Void):Void
  {
    register("gdiInit", function(enable:Bool = true):Bool
    {
      #if (cpp && windows)
      return GDIEffects.init();
      #else
      return false;
      #end
    });

    register("gdiDestroy", function()
    {
      #if (cpp && windows)
      GDIEffects.destroy();
      #end
    });

    register("gdiSetPaused", function(paused:Bool)
    {
      #if (cpp && windows)
      GDIEffects.setPaused(paused);
      #end
    });

    register("gdiIsInitialized", function():Bool
    {
      #if (cpp && windows)
      return GDIEffects.initialized;
      #else
      return false;
      #end
    });

    register("gdiRegisterEffect", function(name:String):Bool
    {
      #if (cpp && windows)
      return GDIEffects.registerEffect(name);
      #else
      return false;
      #end
    });

    register("gdiUnregisterEffect", function(name:String)
    {
      #if (cpp && windows)
      GDIEffects.unregisterEffect(name);
      #end
    });

    register("gdiEnableEffect", function(name:String):Bool
    {
      #if (cpp && windows)
      return GDIEffects.enableEffect(name);
      #else
      return false;
      #end
    });

    register("gdiDisableEffect", function(name:String)
    {
      #if (cpp && windows)
      GDIEffects.disableEffect(name);
      #end
    });

    register("gdiSetEffectWait", function(name:String, waitMs:Float)
    {
      #if (cpp && windows)
      GDIEffects.setEffectWait(name, waitMs);
      #end
    });

    register("gdiIsEffectRegistered", function(name:String):Bool
    {
      #if (cpp && windows)
      return GDIEffects.isEffectRegistered(name);
      #else
      return false;
      #end
    });

    register("gdiGetAvailableEffects", function():Array<String>
    {
      #if (cpp && windows)
      return GDIEffects.availableEffects;
      #else
      return [];
      #end
    });

    register("gdiDrawIcons", function()
    {
      #if (cpp && windows)
      GDIEffects.drawIcons();
      #end
    });

    register("gdiScreenBlink", function()
    {
      #if (cpp && windows)
      GDIEffects.screenBlink();
      #end
    });

    register("gdiScreenGlitches", function()
    {
      #if (cpp && windows)
      GDIEffects.screenGlitches();
      #end
    });

    register("gdiScreenTunnel", function()
    {
      #if (cpp && windows)
      GDIEffects.screenTunnel();
      #end
    });

    register("gdiScreenShake", function()
    {
      #if (cpp && windows)
      GDIEffects.screenShake();
      #end
    });

    register("gdiSetTitleText", function(text:String)
    {
      #if (cpp && windows)
      GDIEffects.setCustomTitleText(text);
      #end
    });
  }

  /**
   * Tells the script author why the call did nothing (shown even without
   * luaDebugMode, so a mod is never silently broken on a standard build).
   * A no-op on Windows native builds, where the real implementations run.
   */
  static function gdiWarning(funk:FunkinLua, fn:String):Void
  {
    #if !(cpp && windows)
    LuaUtils.luaTrace(funk.lua, '$fn: Windows GDI effects require a Windows native build of Phoenix Engine.', true, false, FlxColor.ORANGE);
    #end
  }
}