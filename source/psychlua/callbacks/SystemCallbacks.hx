package psychlua.callbacks;

import debug.system.SystemInfo;
import psychlua.FunkinLua;

/**
 * Read-only process/host system queries from `debug.system.SystemInfo`
 * (`source/debug/system/src/phoenix_system.cpp`) exposed to Lua, Python,
 * HScript and state scripts (`HaxeScript`).
 *
 * Every query fails soft and returns zero (or one for CPU count) when a
 * metric is unavailable on the current target.
 */
class SystemCallbacks
{
  public static function register(funk:FunkinLua):Void
  {
    // Monotonic clock in seconds from an unspecified origin; subtract two readings for elapsed time. Returns 0 on failure.
    FunkinLua.registerFunction("getMonotonicSeconds", function():Float {
      return monotonicSeconds();
    });
    // Cumulative user and kernel CPU seconds consumed by this process across all threads, or 0 when unavailable.
    FunkinLua.registerFunction("getProcessCPUSeconds", function():Float {
      return processCPUSeconds();
    });
    // Number of online logical CPUs on the host (at least 1; not a process affinity or container quota).
    FunkinLua.registerFunction("getLogicalCPUCount", function():Int {
      return logicalCPUCount();
    });
    // Native OS memory page size in bytes, or 0 when unavailable.
    FunkinLua.registerFunction("getPageSize", function():Float {
      return pageSize();
    });
    // Host physical RAM in bytes as a float (avoids 32-bit truncation above 4 GiB), or 0 when unavailable.
    FunkinLua.registerFunction("getTotalPhysicalMemory", function():Float {
      return totalPhysicalMemory();
    });
  }

  /**
   * Seeds the five system queries and a `SystemInfo` namespace object into
   * an HScript or `HaxeScript` interpreter.
   *
   * `debug.system.SystemInfo` is an `extern class` on C++ (`Type.resolveClass`
   * returns `null`) and sandboxed scripts disable imports, so seeding both the
   * flat callbacks and `SystemInfo` keeps every query reachable.
   */
  public static function seedHScript(interp:Dynamic):Void
  {
    if (interp == null || interp.variables == null) return;
    interp.variables.set("getMonotonicSeconds", monotonicSeconds);
    interp.variables.set("getProcessCPUSeconds", processCPUSeconds);
    interp.variables.set("getLogicalCPUCount", logicalCPUCount);
    interp.variables.set("getPageSize", pageSize);
    interp.variables.set("getTotalPhysicalMemory", totalPhysicalMemory);
    interp.variables.set("SystemInfo", createSystemInfoObject());
  }

  /** Creates an interpreter-safe object matching `debug.system.SystemInfo`. */
  public static function createSystemInfoObject():Dynamic
  {
    return {
      monotonicSeconds: monotonicSeconds,
      processCPUSeconds: processCPUSeconds,
      logicalCPUCount: logicalCPUCount,
      pageSize: pageSize,
      totalPhysicalMemory: totalPhysicalMemory
    };
  }

  public static function monotonicSeconds():Float
  {
    try {
      final value:Float = SystemInfo.monotonicSeconds();
      return Math.isNaN(value) || value < 0 ? 0 : value;
    } catch (e:Dynamic) {
      return 0;
    }
  }

  public static function processCPUSeconds():Float
  {
    try {
      final value:Float = SystemInfo.processCPUSeconds();
      return Math.isNaN(value) || value < 0 ? 0 : value;
    } catch (e:Dynamic) {
      return 0;
    }
  }

  public static function logicalCPUCount():Int
  {
    try {
      final count:Int = SystemInfo.logicalCPUCount();
      return count >= 1 ? count : 1;
    } catch (e:Dynamic) {
      return 1;
    }
  }

  public static function pageSize():Float
  {
    try {
      // Explicit Float assignment widens cpp.SizeT on C++ so Convert.toLua
      // marshals it as TFloat rather than an unsupported Dynamic box.
      final bytes:Float = SystemInfo.pageSize();
      return Math.isNaN(bytes) || bytes < 0 ? 0 : bytes;
    } catch (e:Dynamic) {
      return 0;
    }
  }

  public static function totalPhysicalMemory():Float
  {
    try {
      final bytes:Float = SystemInfo.totalPhysicalMemory();
      return Math.isNaN(bytes) || bytes < 0 ? 0 : bytes;
    } catch (e:Dynamic) {
      return 0;
    }
  }
}
