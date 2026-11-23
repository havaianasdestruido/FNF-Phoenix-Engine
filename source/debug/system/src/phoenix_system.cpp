/*
 * Platform implementations for source/debug/system/include/phoenix_system.h.
 *
 * Kept in a dedicated translation unit so <windows.h> (and its ERROR,
 * DELETE, TRANSPARENT, OPAQUE, IGNORE, min/max macros) and POSIX/Apple
 * headers never leak into hxcpp-generated C++ files.
 */
#include "phoenix_system.h"

#if defined(_WIN32)
#ifndef NOMINMAX
#define NOMINMAX
#endif
#ifndef WIN32_LEAN_AND_MEAN
#define WIN32_LEAN_AND_MEAN
#endif
#include <windows.h>
#elif defined(__unix__) || defined(__APPLE__)
#include <unistd.h>
#include <sys/resource.h>
#include <time.h>
#if defined(__APPLE__)
#include <mach/mach_time.h>
#include <sys/sysctl.h>
#endif
#endif

double phoenixMonotonicSeconds(void)
{
#if defined(_WIN32)
  LARGE_INTEGER counter, frequency;
  if (!QueryPerformanceFrequency(&frequency) || frequency.QuadPart <= 0 ||
      !QueryPerformanceCounter(&counter))
    return 0.0;
  return (double)counter.QuadPart / (double)frequency.QuadPart;
#elif defined(__APPLE__)
  mach_timebase_info_data_t scale;
  if (mach_timebase_info(&scale) != KERN_SUCCESS || scale.denom == 0)
    return 0.0;
  return (double)mach_absolute_time() * ((double)scale.numer / scale.denom) / 1e9;
#elif defined(CLOCK_MONOTONIC)
  struct timespec value;
  if (clock_gettime(CLOCK_MONOTONIC, &value) != 0)
    return 0.0;
  return (double)value.tv_sec + (double)value.tv_nsec / 1e9;
#else
  return 0.0;
#endif
}

double phoenixProcessCPUSeconds(void)
{
#if defined(_WIN32)
  FILETIME creation, exitTime, kernel, user;
  ULARGE_INTEGER kernelTicks, userTicks;
  if (!GetProcessTimes(GetCurrentProcess(), &creation, &exitTime, &kernel, &user))
    return 0.0;
  kernelTicks.LowPart = kernel.dwLowDateTime;
  kernelTicks.HighPart = kernel.dwHighDateTime;
  userTicks.LowPart = user.dwLowDateTime;
  userTicks.HighPart = user.dwHighDateTime;
  return ((double)kernelTicks.QuadPart + (double)userTicks.QuadPart) / 1e7;
#elif defined(__unix__) || defined(__APPLE__)
  struct rusage usage;
  if (getrusage(RUSAGE_SELF, &usage) != 0)
    return 0.0;
  return (double)usage.ru_utime.tv_sec + (double)usage.ru_stime.tv_sec +
    ((double)usage.ru_utime.tv_usec + (double)usage.ru_stime.tv_usec) / 1e6;
#else
  return 0.0;
#endif
}

int phoenixLogicalCPUCount(void)
{
#if defined(_WIN32)
  SYSTEM_INFO info;
  GetNativeSystemInfo(&info);
  return info.dwNumberOfProcessors > 0 ? (int)info.dwNumberOfProcessors : 1;
#elif defined(_SC_NPROCESSORS_ONLN)
  long count = sysconf(_SC_NPROCESSORS_ONLN);
  return count > 0 ? (int)count : 1;
#else
  return 1;
#endif
}

size_t phoenixPageSize(void)
{
#if defined(_WIN32)
  SYSTEM_INFO info;
  GetNativeSystemInfo(&info);
  return (size_t)info.dwPageSize;
#elif defined(_SC_PAGESIZE)
  long size = sysconf(_SC_PAGESIZE);
  return size > 0 ? (size_t)size : 0;
#else
  return 0;
#endif
}

double phoenixTotalPhysicalMemory(void)
{
#if defined(_WIN32)
  MEMORYSTATUSEX info;
  info.dwLength = sizeof(info);
  if (!GlobalMemoryStatusEx(&info))
    return 0.0;
  return (double)info.ullTotalPhys;
#elif defined(__APPLE__)
  unsigned long long bytes = 0;
  size_t size = sizeof(bytes);
  if (sysctlbyname("hw.memsize", &bytes, &size, NULL, 0) != 0)
    return 0.0;
  return (double)bytes;
#elif defined(_SC_PHYS_PAGES)
  long pages = sysconf(_SC_PHYS_PAGES);
  size_t pageSize = phoenixPageSize();
  return pages > 0 ? (double)pages * (double)pageSize : 0.0;
#else
  return 0.0;
#endif
}
