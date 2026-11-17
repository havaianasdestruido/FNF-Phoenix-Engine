package psychlua.pystdlib;

import backend.GDIEffects;
import psychlua.PythonScript;

/**
 * Windows GDI desktop effects for Python (Hython) mods.
 *
 * Mirror of `psychlua.callbacks.GdiCallbacks` — keep the function names
 * and the argument order in sync. Everything compiles on every target:
 * on non-Windows builds, or on platforms where an effect does not exist,
 * each function returns its failure value and prints the reason to the
 * debug text instead of doing nothing silently.
 */
class PyGdiLib
{
  public static function register(py:PythonScript):Void
  {
    @:privateAccess
    {
      // ------------------------------------------------------------------
      // Lifecycle
      // ------------------------------------------------------------------
      PythonScript.registerFunction("gdiInit", function():Bool
      {
        #if (cpp && windows)
        return GDIEffects.init();
        #else
        pyGdiWarning(py, 'gdiInit');
        return false;
        #end
      });

      PythonScript.registerFunction("gdiDestroy", function()
      {
        #if (cpp && windows)
        GDIEffects.destroy();
        #else
        pyGdiWarning(py, 'gdiDestroy');
        #end
      });

      PythonScript.registerFunction("gdiSetPaused", function(paused:Bool)
      {
        #if (cpp && windows)
        GDIEffects.setPaused(paused);
        #else
        pyGdiWarning(py, 'gdiSetPaused');
        #end
      });

      PythonScript.registerFunction("gdiIsInitialized", function():Bool
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
      PythonScript.registerFunction("gdiRegisterEffect", function(name:String):Bool
      {
        #if (cpp && windows)
        return GDIEffects.registerEffect(name);
        #else
        pyGdiWarning(py, 'gdiRegisterEffect');
        return false;
        #end
      });

      PythonScript.registerFunction("gdiUnregisterEffect", function(name:String)
      {
        #if (cpp && windows)
        GDIEffects.unregisterEffect(name);
        #else
        pyGdiWarning(py, 'gdiUnregisterEffect');
        #end
      });

      PythonScript.registerFunction("gdiEnableEffect", function(name:String):Bool
      {
        #if (cpp && windows)
        return GDIEffects.enableEffect(name);
        #else
        pyGdiWarning(py, 'gdiEnableEffect');
        return false;
        #end
      });

      PythonScript.registerFunction("gdiDisableEffect", function(name:String)
      {
        #if (cpp && windows)
        GDIEffects.disableEffect(name);
        #else
        pyGdiWarning(py, 'gdiDisableEffect');
        #end
      });

      PythonScript.registerFunction("gdiToggleEffect", function(name:String):Bool
      {
        #if (cpp && windows)
        return GDIEffects.toggleEffect(name);
        #else
        pyGdiWarning(py, 'gdiToggleEffect');
        return false;
        #end
      });

      PythonScript.registerFunction("gdiSetEffectWait", function(name:String, waitMs:Float)
      {
        #if (cpp && windows)
        GDIEffects.setEffectWait(name, waitMs);
        #else
        pyGdiWarning(py, 'gdiSetEffectWait');
        #end
      });

      PythonScript.registerFunction("gdiSetEffectTitleText", function(name:String, text:String)
      {
        #if (cpp && windows)
        GDIEffects.setEffectTitleText(name, text);
        #else
        pyGdiWarning(py, 'gdiSetEffectTitleText');
        #end
      });

      PythonScript.registerFunction("gdiIsEffectRegistered", function(name:String):Bool
      {
        #if (cpp && windows)
        return GDIEffects.isEffectRegistered(name);
        #else
        return false;
        #end
      });

      PythonScript.registerFunction("gdiIsEffectEnabled", function(name:String):Bool
      {
        #if (cpp && windows)
        return GDIEffects.isEffectEnabled(name);
        #else
        return false;
        #end
      });

      PythonScript.registerFunction("gdiGetAvailableEffects", function():Array<String>
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
      PythonScript.registerFunction("gdiDrawIcons", function()
      {
        #if (cpp && windows)
        GDIEffects.drawIcons();
        #else
        pyGdiWarning(py, 'gdiDrawIcons');
        #end
      });

      PythonScript.registerFunction("gdiScreenBlink", function()
      {
        #if (cpp && windows)
        GDIEffects.screenBlink();
        #else
        pyGdiWarning(py, 'gdiScreenBlink');
        #end
      });

      PythonScript.registerFunction("gdiScreenGlitches", function()
      {
        #if (cpp && windows)
        GDIEffects.screenGlitches();
        #else
        pyGdiWarning(py, 'gdiScreenGlitches');
        #end
      });

      PythonScript.registerFunction("gdiScreenTunnel", function()
      {
        #if (cpp && windows)
        GDIEffects.screenTunnel();
        #else
        pyGdiWarning(py, 'gdiScreenTunnel');
        #end
      });

      PythonScript.registerFunction("gdiScreenShake", function()
      {
        #if (cpp && windows)
        GDIEffects.screenShake();
        #else
        pyGdiWarning(py, 'gdiScreenShake');
        #end
      });

      PythonScript.registerFunction("gdiSetTitleText", function(text:String)
      {
        #if (cpp && windows)
        GDIEffects.setCustomTitleText(text);
        #else
        pyGdiWarning(py, 'gdiSetTitleText');
        #end
      });
    }
  }

  /**
   * Tells the script author why the call did nothing.
   * A no-op on Windows native builds, where the real implementations run.
   */
  static function pyGdiWarning(py:PythonScript, fn:String):Void
  {
    #if !(cpp && windows)
    PythonScript.pyTrace(py, '$fn: Windows GDI effects require a Windows native build of Phoenix Engine.', true, false);
    #end
  }
}