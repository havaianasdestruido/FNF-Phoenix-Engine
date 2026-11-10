# Low-level diagnostic utilities

`debug.mem.GetTotalMemory` provides current/peak process resident memory
(`getCurrentRSS()` / `getPeakRSS()`, in bytes, zero when the OS has no answer).
Its header, `source/debug/mem/include/memory.h`, is David Robert Nadeau's
CC-BY 3.0 implementation and matches the copy in Troll Engine
(`source/funkin/api/src/memory.cpp`), including the AIX/Solaris peak-RSS branch.
`debug.system.SystemInfo` adds read-only, header-only native queries on C++
targets (Windows, Linux/Android, macOS/iOS):

| Method | Unit / meaning |
| --- | --- |
| `monotonicSeconds()` | Seconds from an unspecified origin; subtract two readings for elapsed time |
| `processCPUSeconds()` | Cumulative user + kernel CPU seconds, summed over all process threads |
| `logicalCPUCount()` | Online logical processors, at least one |
| `pageSize()` | OS memory page size in bytes |
| `totalPhysicalMemory()` | Host physical RAM in bytes, returned as Float to avoid 32-bit truncation |

```haxe
import debug.system.SystemInfo;

final start = SystemInfo.monotonicSeconds();
final cpuStart = SystemInfo.processCPUSeconds();
// Work to measure...
final elapsed = SystemInfo.monotonicSeconds() - start;
final cpu = SystemInfo.processCPUSeconds() - cpuStart;
// cpu / elapsed measures CPU cores occupied on average, and may exceed 1.
```

Failed/unsupported native queries return zero, except CPU count, which returns
one. Do not divide by an elapsed reading of zero. RAM/CPU count describe the
host, not process affinity, container quotas, free memory, or GC usage. Windows
CPU count reflects the current processor group on very large hosts.

Non-C++ targets use `haxe.Timer.stamp()` for elapsed timing and return zero for
native-only metrics (one for CPU count). No extra libraries are required.
These utilities are opt-in; they do not change the FPS display or sample in the
background.

Standalone Linux C/C++ smoke tests (no engine dependencies):

```sh
bash tests/native/run.sh
```

The runner compiles and links two translation units to verify header-only
linkage, then checks sane query results and nondecreasing time readings. Native
branches for other operating systems should also be validated with their engine
builds.

## Monitor refresh rate

`backend.MonitorRefreshRate.get()` returns the refresh rate of the monitor in
Hz. It is always positive: 60 (`MonitorRefreshRate.FALLBACK`) when nothing is
known.

```haxe
import backend.MonitorRefreshRate;

final hz = MonitorRefreshRate.get();
```

| Method | Meaning |
| --- | --- |
| `get()` | Native reading, else Lime's, else `FALLBACK` |
| `queryNative()` | Rate reported by the X server on desktop Linux; zero elsewhere or when unknown |
| `queryLime()` | `window.displayMode.refreshRate` from Lime; zero without a window |
| `pick(native, lime)` | The selection rule used by `get()` |

The Linux query is ported from
[Troll Engine](https://github.com/troll-slaiyers/FNF-Troll-Engine)
(`source/funkin/api/src/refreshrate.cpp`). It opens its own connection to the X
server (X11 or XWayland) and reads the current rate through XRandR. Unlike the
original it returns zero instead of crashing when there is no X server (a
Wayland-only or headless session) or no RandR extension, and it frees the
screen configuration it requests.

Unlike the other native helpers this one is not header-only:
`source/backend/native/src/phoenix_refresh_rate.cpp` is compiled as its own
file group by `source/backend/native/refresh_rate_build.xml`, because `Xlib.h`
defines macros (`None`, `Bool`, `Status`, ...) that break hxcpp-generated C++.
Linux builds therefore need the X11 and XRandR development files (see
BUILDING.md) and link `-lX11 -lXrandr`. Android, Windows and macOS builds do
not compile or link any of it.

The "Video Framerate" default in the Game Renderer settings uses this value.

Tests: `bash tests/haxe/run-monitor-refresh-rate.sh` (selection rule, Lime
fallback, generated C++ per target) and `bash tests/native/run.sh` (every
failure path against an Xlib test double, plus the real Xlib when its headers
are installed).

## Hardware detection

`backend.Native` reports the GPU, the GPU driver, the CPU and the operating
system of the machine the game runs on. It is used by the crash handler (every
crash log ends with the hardware details) and is exposed to Lua, Python and
HScript scripts.

```haxe
import backend.Native;

trace(Native.buildSystemInfo());
trace(Native.getGPUName());          // "NVIDIA GeForce RTX 3060"
trace(Native.getGPUDriverVersion());  // "535.104.05"
trace(Native.getCPUVendor());         // "Intel"
```

The GPU part is read from the OpenGL context (`GL.VENDOR`, `GL.RENDERER`,
`GL.VERSION`) and is ported from the Psych Plus Engine
(`source/backend/Native.hx`, <https://github.com/Psych-Plus-Team/FNF-PlusEngine>).
The CPU and the operating system come from the header-only native layer in
`source/backend/native/include/phoenix_hardware.h`, which reads the Windows
registry, `sysctl` on macOS and `/proc/cpuinfo` plus `uname` on Linux/Android.

Every value degrades gracefully: without a render context or without the native
queries the engine reports `Unknown` instead of failing, and non-C++ targets
compile a stub that returns empty strings.

Standalone C/C++ smoke tests for the native layer:

```sh
bash tests/native/run.sh
```
