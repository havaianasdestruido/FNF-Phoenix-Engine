package psychlua.pystdlib;

import flixel.util.FlxColor;
import psychlua.PythonScript;
import psychlua.callbacks.FilterCallbacks;

/**
 * Python binding for the filter / chainable-effect API.
 *
 * The whole surface (names, argument order, defaults, presets, warnings) lives
 * in `psychlua.callbacks.FilterCallbacks.api()`, so Lua, HScript and Python
 * cannot drift apart. This class only tells it where to bind and where to send
 * warnings.
 */
class PyFilterLib
{
  public static function register(py:PythonScript):Void
  {
    @:privateAccess {
      FilterCallbacks.api(PythonScript.registerFunction, function(message:String, color:FlxColor) {
        py.pyTrace(message, false, false, color);
      });
    }
  }
}
