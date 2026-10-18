/*
 * Hardware queries for Phoenix Engine.
 *
 * Header-only: hxcpp compiles every class into its own translation unit, so
 * the helpers below use internal linkage and can be included more than once.
 *
 * Every query writes a NUL terminated string into a caller supplied buffer and
 * returns 1 when the information was found, 0 otherwise. The engine treats an
 * empty result as "Unknown", so platforms without support (or without the
 * needed permissions) degrade gracefully instead of failing.
 *
 * Author: Phoenix Engine Contributors
 * License: MIT (see LICENSE in the repository root)
 */

#ifndef PHOENIX_HARDWARE_H
#define PHOENIX_HARDWARE_H

#include <stddef.h>
#include <string.h>

#if defined(_WIN32)
#include <windows.h>
#elif defined(__APPLE__)
#include <sys/sysctl.h>
#include <sys/utsname.h>
#elif defined(__linux__)
#include <stdio.h>
#include <sys/utsname.h>
#endif

/* Not every helper is used on every platform, so silence the "unused
 * function" warnings the different build targets would produce. */
#if defined(__GNUC__) || defined(__clang__)
#define PHOENIX_UNUSED __attribute__((unused))
#else
#define PHOENIX_UNUSED
#endif

/* ------------------------------------------------------------------------ */
/* Shared helpers                                                            */
/* ------------------------------------------------------------------------ */

/* Copies at most capacity - 1 bytes of source into destination and NUL
 * terminates the result. Returns 1 when something was copied. */
static PHOENIX_UNUSED int phoenixCopyText(char *destination, size_t capacity, const char *source)
{
  size_t length;
  if (destination == NULL || capacity == 0)
    return 0;
  destination[0] = 0;
  if (source == NULL)
    return 0;
  length = strlen(source);
  if (length > capacity - 1)
    length = capacity - 1;
  memcpy(destination, source, length);
  destination[length] = 0;
  return 1;
}

/* Removes trailing whitespace and control characters (CR, LF, tabs). */
static PHOENIX_UNUSED void phoenixTrimTrailing(char *text)
{
  size_t length;
  if (text == NULL)
    return;
  length = strlen(text);
  while (length > 0 && (unsigned char)text[length - 1] <= ' ')
    text[--length] = 0;
}

/* Appends an unsigned number to a string buffer without using snprintf, so
 * the header also builds with the older MSVC runtimes. */
static PHOENIX_UNUSED void phoenixAppendNumber(char *buffer, size_t capacity, size_t *length, unsigned long value)
{
  char digits[24];
  int count = 0;
  if (buffer == NULL || length == NULL || capacity == 0)
    return;
  if (value == 0)
    digits[count++] = '0';
  while (value > 0 && count < 23)
  {
    digits[count++] = (char)('0' + (int)(value % 10));
    value /= 10;
  }
  while (count > 0 && *length + 1 < capacity)
    buffer[(*length)++] = digits[--count];
}

/* ------------------------------------------------------------------------ */
/* Windows                                                                   */
/* ------------------------------------------------------------------------ */

#if defined(_WIN32)

/* Reads a string value out of the CPU description key of the registry. */
static PHOENIX_UNUSED int phoenixReadRegistryValue(const char *valueName, char *out, size_t capacity)
{
  HKEY key;
  DWORD type = 0;
  DWORD size;
  LONG status;
  if (out == NULL || capacity == 0 || valueName == NULL)
    return 0;
  out[0] = 0;
  status = RegOpenKeyExA(HKEY_LOCAL_MACHINE, "HARDWARE\\DESCRIPTION\\System\\CentralProcessor\\0", 0,
    KEY_READ, &key);
  if (status != ERROR_SUCCESS)
    return 0;
  size = (DWORD)capacity;
  status = RegQueryValueExA(key, valueName, NULL, &type, (LPBYTE)out, &size);
  RegCloseKey(key);
  if (status != ERROR_SUCCESS)
  {
    out[0] = 0;
    return 0;
  }
  out[capacity - 1] = 0;
  phoenixTrimTrailing(out);
  return out[0] != 0;
}

/* The real Windows version, read through RtlGetVersion so the value is not
 * capped by the application manifest. */
static PHOENIX_UNUSED int phoenixWindowsOsVersion(char *out, size_t capacity)
{
  OSVERSIONINFOW versionInfo;
  typedef LONG(WINAPI *phoenixRtlGetVersionFn)(OSVERSIONINFOW *);
  phoenixRtlGetVersionFn rtlGetVersion = NULL;
  HMODULE ntdll;
  size_t length = 0;
  if (out == NULL || capacity == 0)
    return 0;
  out[0] = 0;
  memset(&versionInfo, 0, sizeof(versionInfo));
  versionInfo.dwOSVersionInfoSize = sizeof(versionInfo);
  ntdll = GetModuleHandleA("ntdll.dll");
  if (ntdll != NULL)
    rtlGetVersion = (phoenixRtlGetVersionFn)GetProcAddress(ntdll, "RtlGetVersion");
  if (rtlGetVersion == NULL || rtlGetVersion(&versionInfo) != 0)
    return 0;
  phoenixAppendNumber(out, capacity, &length, (unsigned long)versionInfo.dwMajorVersion);
  if (length + 1 < capacity)
    out[length++] = '.';
  phoenixAppendNumber(out, capacity, &length, (unsigned long)versionInfo.dwMinorVersion);
  if (length + 1 < capacity)
    out[length++] = '.';
  phoenixAppendNumber(out, capacity, &length, (unsigned long)versionInfo.dwBuildNumber);
  out[length] = 0;
  return length > 0;
}

static PHOENIX_UNUSED int phoenixWindowsCpuVendor(char *out, size_t capacity)
{
  return phoenixReadRegistryValue("VendorIdentifier", out, capacity);
}

static PHOENIX_UNUSED int phoenixWindowsCpuModel(char *out, size_t capacity)
{
  return phoenixReadRegistryValue("ProcessorNameString", out, capacity);
}

static PHOENIX_UNUSED int phoenixWindowsOsName(char *out, size_t capacity)
{
  return phoenixCopyText(out, capacity, "Windows");
}

#endif /* _WIN32 */

/* ------------------------------------------------------------------------ */
/* macOS                                                                     */
/* ------------------------------------------------------------------------ */

#if defined(__APPLE__)

/* Reads a sysctl string, for example "machdep.cpu.brand_string". */
static PHOENIX_UNUSED int phoenixSysctlString(const char *name, char *out, size_t capacity)
{
  size_t size = capacity;
  if (out == NULL || capacity == 0 || name == NULL)
    return 0;
  out[0] = 0;
  if (sysctlbyname(name, out, &size, NULL, 0) != 0)
  {
    out[0] = 0;
    return 0;
  }
  out[capacity - 1] = 0;
  phoenixTrimTrailing(out);
  return out[0] != 0;
}

static PHOENIX_UNUSED int phoenixAppleCpuVendor(char *out, size_t capacity)
{
  return phoenixSysctlString("machdep.cpu.vendor", out, capacity);
}

static PHOENIX_UNUSED int phoenixAppleCpuModel(char *out, size_t capacity)
{
  return phoenixSysctlString("machdep.cpu.brand_string", out, capacity);
}

static PHOENIX_UNUSED int phoenixAppleOsName(char *out, size_t capacity)
{
  return phoenixCopyText(out, capacity, "macOS");
}

static PHOENIX_UNUSED int phoenixAppleOsVersion(char *out, size_t capacity)
{
  return phoenixSysctlString("kern.osproductversion", out, capacity);
}

#endif /* __APPLE__ */

/* ------------------------------------------------------------------------ */
/* Linux and Android                                                         */
/* ------------------------------------------------------------------------ */

#if defined(__linux__)

/* Reads a single "key : value" pair out of /proc/cpuinfo. */
static PHOENIX_UNUSED int phoenixReadCpuInfoField(const char *key, char *out, size_t capacity)
{
  FILE *file;
  char line[512];
  size_t keyLength;
  int found = 0;
  if (out == NULL || capacity == 0 || key == NULL)
    return 0;
  out[0] = 0;
  file = fopen("/proc/cpuinfo", "rb");
  if (file == NULL)
    return 0;
  keyLength = strlen(key);
  while (fgets(line, (int)sizeof(line), file) != NULL)
  {
    char *separator;
    if (strncmp(line, key, keyLength) != 0)
      continue;
    separator = strchr(line, ':');
    if (separator == NULL)
      continue;
    separator++;
    while (*separator != 0 && (unsigned char)*separator <= ' ')
      separator++;
    phoenixTrimTrailing(separator);
    phoenixCopyText(out, capacity, separator);
    found = out[0] != 0;
    break;
  }
  fclose(file);
  return found;
}

/* ARM CPUs report the vendor as a number instead of a name. */
static PHOENIX_UNUSED const char *phoenixLinuxVendorFromImplementer(const char *implementer)
{
  if (implementer == NULL)
    return NULL;
  if (strcmp(implementer, "0x41") == 0)
    return "ARM";
  if (strcmp(implementer, "0x42") == 0)
    return "Broadcom";
  if (strcmp(implementer, "0x4e") == 0)
    return "NVIDIA";
  if (strcmp(implementer, "0x50") == 0)
    return "Ampere";
  if (strcmp(implementer, "0x51") == 0)
    return "Qualcomm";
  if (strcmp(implementer, "0x56") == 0)
    return "Marvell";
  if (strcmp(implementer, "0x61") == 0)
    return "Apple";
  if (strcmp(implementer, "0x69") == 0)
    return "Intel";
  if (strcmp(implementer, "0xc0") == 0)
    return "Ampere";
  return NULL;
}

static PHOENIX_UNUSED int phoenixLinuxCpuVendor(char *out, size_t capacity)
{
  char value[256];
  if (phoenixReadCpuInfoField("vendor_id", value, sizeof(value)))
    return phoenixCopyText(out, capacity, value);
  if (phoenixReadCpuInfoField("CPU implementer", value, sizeof(value)))
  {
    const char *vendor = phoenixLinuxVendorFromImplementer(value);
    if (vendor != NULL)
      return phoenixCopyText(out, capacity, vendor);
    return phoenixCopyText(out, capacity, value);
  }
  if (out != NULL && capacity > 0)
    out[0] = 0;
  return 0;
}

static PHOENIX_UNUSED int phoenixLinuxCpuModel(char *out, size_t capacity)
{
  char value[256];
  if (phoenixReadCpuInfoField("model name", value, sizeof(value)))
    return phoenixCopyText(out, capacity, value);
  if (phoenixReadCpuInfoField("Hardware", value, sizeof(value)))
    return phoenixCopyText(out, capacity, value);
  if (phoenixReadCpuInfoField("Processor", value, sizeof(value)))
    return phoenixCopyText(out, capacity, value);
  if (out != NULL && capacity > 0)
    out[0] = 0;
  return 0;
}

static PHOENIX_UNUSED int phoenixLinuxOsName(char *out, size_t capacity)
{
  struct utsname info;
  if (uname(&info) != 0)
  {
    if (out != NULL && capacity > 0)
      out[0] = 0;
    return 0;
  }
  return phoenixCopyText(out, capacity, info.sysname);
}

static PHOENIX_UNUSED int phoenixLinuxOsVersion(char *out, size_t capacity)
{
  struct utsname info;
  if (uname(&info) != 0)
  {
    if (out != NULL && capacity > 0)
      out[0] = 0;
    return 0;
  }
  return phoenixCopyText(out, capacity, info.release);
}

#endif /* __linux__ */

/* ------------------------------------------------------------------------ */
/* Platform independent entry points                                          */
/* ------------------------------------------------------------------------ */

/* CPU vendor, for example "GenuineIntel" or "ARM". */
static PHOENIX_UNUSED int phoenixCpuVendor(char *out, size_t capacity)
{
#if defined(_WIN32)
  return phoenixWindowsCpuVendor(out, capacity);
#elif defined(__APPLE__)
  return phoenixAppleCpuVendor(out, capacity);
#elif defined(__linux__)
  return phoenixLinuxCpuVendor(out, capacity);
#else
  if (out != NULL && capacity > 0)
    out[0] = 0;
  return 0;
#endif
}

/* CPU model, for example "Intel(R) Core(TM) i7-9700K CPU @ 3.60GHz". */
static PHOENIX_UNUSED int phoenixCpuModel(char *out, size_t capacity)
{
#if defined(_WIN32)
  return phoenixWindowsCpuModel(out, capacity);
#elif defined(__APPLE__)
  return phoenixAppleCpuModel(out, capacity);
#elif defined(__linux__)
  return phoenixLinuxCpuModel(out, capacity);
#else
  if (out != NULL && capacity > 0)
    out[0] = 0;
  return 0;
#endif
}

/* Operating system name, for example "Windows" or "Linux". */
static PHOENIX_UNUSED int phoenixOsName(char *out, size_t capacity)
{
#if defined(_WIN32)
  return phoenixWindowsOsName(out, capacity);
#elif defined(__APPLE__)
  return phoenixAppleOsName(out, capacity);
#elif defined(__linux__)
  return phoenixLinuxOsName(out, capacity);
#else
  if (out != NULL && capacity > 0)
    out[0] = 0;
  return 0;
#endif
}

/* Operating system version, for example "10.0.19045" or "5.15.0". */
static PHOENIX_UNUSED int phoenixOsVersion(char *out, size_t capacity)
{
#if defined(_WIN32)
  return phoenixWindowsOsVersion(out, capacity);
#elif defined(__APPLE__)
  return phoenixAppleOsVersion(out, capacity);
#elif defined(__linux__)
  return phoenixLinuxOsVersion(out, capacity);
#else
  if (out != NULL && capacity > 0)
    out[0] = 0;
  return 0;
#endif
}

#endif /* PHOENIX_HARDWARE_H */
