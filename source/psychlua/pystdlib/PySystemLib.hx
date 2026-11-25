package psychlua.pystdlib;

import psychlua.PythonScript;
import psychlua.callbacks.SystemCallbacks;

/**
 * Python mirror of `psychlua.callbacks.SystemCallbacks`.
 */
class PySystemLib
{
  public static function register(py:PythonScript):Void
  {
    // Monotonic clock in seconds from an unspecified origin; subtract two readings for elapsed time. Returns 0 on failure.
    PythonScript.registerFunction("getMonotonicSeconds", function():Float {
      return SystemCallbacks.monotonicSeconds();
    });
    // Cumulative user and kernel CPU seconds consumed by this process across all threads, or 0 when unavailable.
    PythonScript.registerFunction("getProcessCPUSeconds", function():Float {
      return SystemCallbacks.processCPUSeconds();
    });
    // Number of online logical CPUs on the host (at least 1; not a process affinity or container quota).
    PythonScript.registerFunction("getLogicalCPUCount", function():Int {
      return SystemCallbacks.logicalCPUCount();
    });
    // Native OS memory page size in bytes, or 0 when unavailable.
    PythonScript.registerFunction("getPageSize", function():Float {
      return SystemCallbacks.pageSize();
    });
    // Host physical RAM in bytes as a float (avoids 32-bit truncation above 4 GiB), or 0 when unavailable.
    PythonScript.registerFunction("getTotalPhysicalMemory", function():Float {
      return SystemCallbacks.totalPhysicalMemory();
    });
  }
}
