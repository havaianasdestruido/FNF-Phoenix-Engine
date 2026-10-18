# Low-level diagnostic utilities

`debug.mem.GetTotalMemory` provides current/peak process resident memory.
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
python3 -m unittest discover -s tests -p 'test_native_system.py' -v
```

The tests compile and link two translation units to verify header-only linkage,
then check sane query results and nondecreasing time readings. Native branches
for other operating systems should also be validated with their engine builds.

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
python3 -m unittest discover -s tests -p 'test_native_hardware.py' -v
```
