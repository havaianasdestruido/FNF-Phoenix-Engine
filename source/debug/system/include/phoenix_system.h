#ifndef PHOENIX_SYSTEM_H
#define PHOENIX_SYSTEM_H

#include <stddef.h>

/*
 * Native host/process system queries for Phoenix Engine.
 *
 * Unlike header-only helpers, the platform implementations live in
 * ../src/phoenix_system.cpp instead of this header: on Windows, <windows.h>
 * pulls in <wingdi.h>, which defines macros such as ERROR (0), DELETE,
 * TRANSPARENT, OPAQUE and IGNORE that break hxcpp-generated C++ (e.g.
 * Flixel's LogStyle::ERROR in Benchmark.cpp). Keeping OS headers inside
 * phoenix_system.cpp prevents macro leakage into any Haxe translation unit.
 *
 * Queries return zero on failure/unsupported platforms, except CPU count (one).
 * These functions observe the host; they do not change scheduling or allocate RAM.
 */
#ifdef __cplusplus
extern "C" {
#endif

/** Monotonic seconds from an unspecified origin; use differences, not dates. */
double phoenixMonotonicSeconds(void);

/** Cumulative user + kernel CPU seconds for this process (all threads). */
double phoenixProcessCPUSeconds(void);

/** Online logical CPUs; not necessarily the process affinity/container limit. */
int phoenixLogicalCPUCount(void);

/** OS memory page size in bytes, or zero when unavailable. */
size_t phoenixPageSize(void);

/** Host physical RAM in bytes, not free memory or a container allocation limit.
 * A double avoids truncating machines with >4 GiB RAM on 32-bit targets.
 */
double phoenixTotalPhysicalMemory(void);

#ifdef __cplusplus
}
#endif

#endif
