package psychlua.callbacks;

import backend.Native;
import headers.PsychLua;
import psychlua.FunkinLua;

// REFACTOR: extracted from psychlua.FunkinLua (hardware detection API)
class HardwareCallbacks
{
  public static function register(funk:FunkinLua):Void {
    // Returns a human readable report of the hardware the game runs on.
    FunkinLua.registerFunction("getSystemInfo", function() {
      return query(funk, "getSystemInfo", () -> Native.buildSystemInfo());
    });
    // Returns the GPU model, for example "NVIDIA GeForce RTX 3060".
    FunkinLua.registerFunction("getGPUName", function() {
      return query(funk, "getGPUName", () -> Native.getGPUName());
    });
    // Returns the GPU vendor, for example "NVIDIA".
    FunkinLua.registerFunction("getGPUVendor", function() {
      return query(funk, "getGPUVendor", () -> Native.getGPUVendor());
    });
    // Returns the GPU driver version, for example "535.104.05".
    FunkinLua.registerFunction("getGPUDriverVersion", function() {
      return query(funk, "getGPUDriverVersion", () -> Native.getGPUDriverVersion());
    });
    // Returns the CPU model, for example "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz".
    FunkinLua.registerFunction("getCPUName", function() {
      return query(funk, "getCPUName", () -> Native.getCPUName());
    });
    // Returns the CPU vendor, for example "Intel".
    FunkinLua.registerFunction("getCPUVendor", function() {
      return query(funk, "getCPUVendor", () -> Native.getCPUVendor());
    });
    // Returns the operating system, for example "Windows".
    FunkinLua.registerFunction("getOSName", function() {
      return query(funk, "getOSName", () -> Native.getOSName());
    });
    // Returns the operating system version, for example "10.0.19045".
    FunkinLua.registerFunction("getOSVersion", function() {
      return query(funk, "getOSVersion", () -> Native.getOSVersion());
    });
    // Returns the graphics API version, for example "OpenGL 4.6".
    FunkinLua.registerFunction("getGraphicsApi", function() {
      return query(funk, "getGraphicsApi", () -> Native.getGraphicsApi());
    });
    // Returns the audio backend, for example "OpenAL Soft | 1.23.1".
    FunkinLua.registerFunction("getAudioApi", function() {
      return query(funk, "getAudioApi", () -> Native.getSystemInfo().audioApi);
    });
    // Returns the hardware information as a table with a field per value.
    FunkinLua.registerFunction("getSystemInfoTable", function() {
      try {
        return Native.getSystemInfo();
      } catch (e:Dynamic) {
        LuaUtils.luaTrace(funk.lua, "getSystemInfoTable failed: " + Std.string(e), true, false, FlxColor.RED);
        return null;
      }
    });
  }

  /**
   * Runs a hardware query and reports a failure instead of throwing, so a
   * script never dies because a value could not be read.
   */
  static function query(funk:FunkinLua, name:String, value:() -> String):String {
    try {
      return value();
    } catch (e:Dynamic) {
      LuaUtils.luaTrace(funk.lua, name + " failed: " + Std.string(e), true, false, FlxColor.RED);
      return Native.UNKNOWN;
    }
  }
}
