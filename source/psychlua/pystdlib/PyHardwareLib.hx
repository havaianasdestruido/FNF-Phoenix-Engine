package psychlua.pystdlib;

import backend.Native;
import psychlua.PythonScript;

// REFACTOR: extracted from psychlua.PythonScript (hardware detection API)
class PyHardwareLib
{
  public static function register(py:PythonScript):Void {
    // Returns a human readable report of the hardware the game runs on.
    PythonScript.registerFunction("getSystemInfo", function() {
      return query(py, "getSystemInfo", () -> Native.buildSystemInfo());
    });
    // Returns the GPU model, for example "NVIDIA GeForce RTX 3060".
    PythonScript.registerFunction("getGPUName", function() {
      return query(py, "getGPUName", () -> Native.getGPUName());
    });
    // Returns the GPU vendor, for example "NVIDIA".
    PythonScript.registerFunction("getGPUVendor", function() {
      return query(py, "getGPUVendor", () -> Native.getGPUVendor());
    });
    // Returns the GPU driver version, for example "535.104.05".
    PythonScript.registerFunction("getGPUDriverVersion", function() {
      return query(py, "getGPUDriverVersion", () -> Native.getGPUDriverVersion());
    });
    // Returns the CPU model, for example "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz".
    PythonScript.registerFunction("getCPUName", function() {
      return query(py, "getCPUName", () -> Native.getCPUName());
    });
    // Returns the CPU vendor, for example "Intel".
    PythonScript.registerFunction("getCPUVendor", function() {
      return query(py, "getCPUVendor", () -> Native.getCPUVendor());
    });
    // Returns the operating system, for example "Windows".
    PythonScript.registerFunction("getOSName", function() {
      return query(py, "getOSName", () -> Native.getOSName());
    });
    // Returns the operating system version, for example "10.0.19045".
    PythonScript.registerFunction("getOSVersion", function() {
      return query(py, "getOSVersion", () -> Native.getOSVersion());
    });
    // Returns the graphics API version, for example "OpenGL 4.6".
    PythonScript.registerFunction("getGraphicsApi", function() {
      return query(py, "getGraphicsApi", () -> Native.getGraphicsApi());
    });
    // Returns the audio backend, for example "OpenAL Soft | 1.23.1".
    PythonScript.registerFunction("getAudioApi", function() {
      return query(py, "getAudioApi", () -> Native.getSystemInfo().audioApi);
    });
  }

  /**
   * Runs a hardware query and reports a failure instead of throwing, so a
   * script never dies because a value could not be read.
   */
  static function query(py:PythonScript, name:String, value:() -> String):String {
    try {
      return value();
    } catch (e:Dynamic) {
      py.pyTrace(name + " failed: " + Std.string(e), true, false, FlxColor.RED);
      return Native.UNKNOWN;
    }
  }
}
