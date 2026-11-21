#!/usr/bin/env bash
# Standalone C/C++ smoke tests for the native diagnostic headers, the Windows
# window helpers and the Linux refresh rate query. No Haxe/Lime/Android
# dependencies.
#
#   CC / CXX              override the host compilers (default cc / c++)
#   PHOENIX_WINDOWS_CXX   optional Windows-targeting compiler; when set, the
#                         real phoenix_window.h is also compiled against the
#                         actual Windows SDK (e.g. x86_64-w64-mingw32-g++).
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
CC="${CC:-cc}"
CXX="${CXX:-c++}"
# Exported so the C++ specs can recompile the translation units they inspect.
export CC CXX
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --- phoenix_system: C and C++ callers linked against phoenix_system.cpp ---
# Also verify the header does not leak Win32 macros (ERROR, DELETE, etc.)
# into hxcpp-generated C++ callers such as Benchmark.cpp + LogStyle.h.
cat > "$work/system_other.c" <<'EOF'
#include "phoenix_system.h"
double other(void) { return phoenixMonotonicSeconds(); }
EOF
cat > "$work/system_main.c" <<'EOF'
#include "phoenix_system.h"
#include "phoenix_system.h"
#include <assert.h>
#ifdef ERROR
#error "phoenix_system.h leaked ERROR macro"
#endif
extern double other(void);
int main(void)
{
  double start = phoenixMonotonicSeconds();
  double cpu = phoenixProcessCPUSeconds();
  volatile unsigned long sum = 0;
  unsigned long i;
  assert(start > 0.0);
  assert(phoenixLogicalCPUCount() >= 1);
  assert(phoenixPageSize() > 0);
  assert(phoenixTotalPhysicalMemory() >= (double)phoenixPageSize());
  for (i = 0; i < 1000000; ++i) sum += i;
  assert(phoenixProcessCPUSeconds() >= cpu);
  assert(other() >= start);
  (void)sum;
  return 0;
}
EOF
if command -v "$CXX" >/dev/null; then
  "$CXX" -std=c++11 -Wall -Wextra -Werror -I source/debug/system/include \
    -c source/debug/system/src/phoenix_system.cpp -o "$work/phoenix_system.o"
  for lang in c cpp; do
    if [ "$lang" = c ]; then
      comp="$CC"; std=gnu99
    else
      comp="$CXX"; std=c++11
    fi
    command -v "$comp" >/dev/null || { echo "skip system smoke ($comp unavailable)"; continue; }
    "$comp" "-std=$std" -Wall -Wextra -Werror -I source/debug/system/include \
      -c "$work/system_main.c" -o "$work/system_main_$lang.o"
    "$comp" "-std=$std" -Wall -Wextra -Werror -I source/debug/system/include \
      -c "$work/system_other.c" -o "$work/system_other_$lang.o"
    "$CXX" "$work/system_main_$lang.o" "$work/system_other_$lang.o" "$work/phoenix_system.o" \
      -o "$work/system_$lang"
    "$work/system_$lang"
  done
  # Also compile phoenix_system.cpp against the Win32 test double so Windows
  # paths (QueryPerformanceCounter, GetProcessTimes, GetNativeSystemInfo,
  # GlobalMemoryStatusEx) are verified locally too.
  cat > "$work/win_sys_stub.h" <<'EOF'
#pragma once
#include <stdint.h>
typedef int BOOL;
typedef unsigned long DWORD;
typedef long long LONGLONG;
typedef unsigned long long ULONGLONG;
typedef void* HANDLE;
typedef union { struct { DWORD LowPart; long HighPart; }; LONGLONG QuadPart; } LARGE_INTEGER;
typedef union { struct { DWORD LowPart; DWORD HighPart; }; ULONGLONG QuadPart; } ULARGE_INTEGER;
typedef struct { DWORD dwLowDateTime; DWORD dwHighDateTime; } FILETIME;
typedef struct { DWORD dwPageSize; DWORD dwNumberOfProcessors; } SYSTEM_INFO;
typedef struct { DWORD dwLength; ULONGLONG ullTotalPhys; } MEMORYSTATUSEX;
#define ERROR 0
inline BOOL QueryPerformanceFrequency(LARGE_INTEGER* f) { f->QuadPart = 1000000; return 1; }
inline BOOL QueryPerformanceCounter(LARGE_INTEGER* c) { c->QuadPart = 123456; return 1; }
inline HANDLE GetCurrentProcess() { return (HANDLE)1; }
inline BOOL GetProcessTimes(HANDLE, FILETIME* a, FILETIME* b, FILETIME* k, FILETIME* u) {
  a->dwLowDateTime = a->dwHighDateTime = b->dwLowDateTime = b->dwHighDateTime = 0;
  k->dwLowDateTime = 100; k->dwHighDateTime = 0;
  u->dwLowDateTime = 200; u->dwHighDateTime = 0;
  return 1;
}
inline void GetNativeSystemInfo(SYSTEM_INFO* s) { s->dwPageSize = 4096; s->dwNumberOfProcessors = 4; }
inline BOOL GlobalMemoryStatusEx(MEMORYSTATUSEX* m) { m->ullTotalPhys = 1024ULL * 1024 * 1024; return 1; }
EOF
  mkdir -p "$work/win_sys_inc"
  cp "$work/win_sys_stub.h" "$work/win_sys_inc/windows.h"
  "$CXX" -std=c++11 -Wall -Wextra -Werror -D_WIN32 -I "$work/win_sys_inc" \
    -I source/debug/system/include -c source/debug/system/src/phoenix_system.cpp \
    -o "$work/phoenix_system_win.o"
  echo "phoenix_system smoke passed"
else
  echo "skip system smoke ($CXX unavailable)"
fi

# --- memory.h (process RSS): compile as C and C++, two translation units -----
cat > "$work/memory_other.c" <<'EOF'
#include "memory.h"
size_t other(void) { return getCurrentRSS() + getPeakRSS(); }
EOF
cat > "$work/memory_main.c" <<'EOF'
#include "memory.h"
#include "memory.h"
#include <assert.h>
extern size_t other(void);
int main(void)
{
  size_t current = getCurrentRSS();
  size_t peak = getPeakRSS();
#if defined(_WIN32) || defined(__linux__) || (defined(__APPLE__) && defined(__MACH__))
  /* Both readings are implemented on these systems; zero means "unknown". */
  assert(current > 0);
  assert(peak > 0);
#endif
  assert(other() >= current || other() >= peak);
  return 0;
}
EOF
for lang in c cpp; do
  if [ "$lang" = c ]; then comp="$CC"; std=gnu99; else comp="$CXX"; std=c++11; fi
  command -v "$comp" >/dev/null || { echo "skip memory smoke ($comp unavailable)"; continue; }
  "$comp" "-std=$std" -Wall -Wextra -Werror -I source/debug/mem/include \
    "$work/memory_main.c" "$work/memory_other.c" -o "$work/memory_$lang"
  "$work/memory_$lang"
done
echo "memory (RSS) smoke passed"

# --- phoenix_hardware.h: compile as C and C++, two translation units ---------
cat > "$work/hardware_other.c" <<'EOF'
#include "phoenix_hardware.h"
int other(void)
{
  char buffer[64];
  return phoenixCpuModel(buffer, sizeof(buffer));
}
EOF
cat > "$work/hardware_main.c" <<'EOF'
#include "phoenix_hardware.h"
#include "phoenix_hardware.h"
#include <assert.h>
#include <string.h>
extern int other(void);
int main(void)
{
  char vendor[64], model[64], osName[64], osVersion[64];
  int ok;
  memset(vendor, 0, sizeof(vendor));
  memset(model, 0, sizeof(model));
  memset(osName, 0, sizeof(osName));
  memset(osVersion, 0, sizeof(osVersion));
  ok = phoenixCpuVendor(vendor, sizeof(vendor));
  assert(ok == 0 || ok == 1);
  assert(vendor[sizeof(vendor) - 1] == 0);
  ok = phoenixCpuModel(model, sizeof(model));
  assert(ok == 0 || ok == 1);
  assert(model[sizeof(model) - 1] == 0);
  ok = phoenixOsName(osName, sizeof(osName));
  assert(ok == 0 || ok == 1);
  assert(osName[sizeof(osName) - 1] == 0);
  ok = phoenixOsVersion(osVersion, sizeof(osVersion));
  assert(ok == 0 || ok == 1);
  assert(osVersion[sizeof(osVersion) - 1] == 0);
  {
    char tiny[1];
    tiny[0] = 'x';
    phoenixCpuModel(tiny, sizeof(tiny));
    assert(tiny[0] == 0);
  }
  assert(other() >= 0);
  return 0;
}
EOF
for lang in c cpp; do
  if [ "$lang" = c ]; then comp="$CC"; std=gnu99; else comp="$CXX"; std=c++11; fi
  command -v "$comp" >/dev/null || { echo "skip hardware smoke ($comp unavailable)"; continue; }
  "$comp" "-std=$std" -Wall -Wextra -Werror -I source/backend/native/include \
    "$work/hardware_main.c" "$work/hardware_other.c" -o "$work/hardware_$lang"
  "$work/hardware_$lang"
done
echo "phoenix_hardware smoke passed"

# --- Windows window lookup / transparency / DWM, against the Win32 double ----
if command -v "$CXX" >/dev/null; then
  "$CXX" -std=c++11 -Wall -Wextra -Werror -D_WIN32 \
    -I tests/native/windows -I source/backend/native/include \
    tests/native/test_window_lookup.cpp -o "$work/window-test"
  "$work/window-test"
else
  echo "skip window lookup ($CXX unavailable)"
fi

# --- META_HORROR native header self-sufficiency, against the Win32 double ----
# Two translation units verify the header-only (static) linkage that hxcpp
# requires because it includes native metadata twice.
if command -v "$CXX" >/dev/null; then
  printf '#include <windows.h>\n#include "phoenix_meta_horror.h"\ndouble otherUptime() { return phoenixMetaSystemUptime(); }\n' > "$work/meta_other.cpp"
  awk '{ if ($0 ~ /int main\(\)/) print "extern double otherUptime();"; print }' \
    tests/native/test_meta_horror_header.cpp > "$work/meta_main.cpp"
  "$CXX" -std=c++11 -Wall -Wextra -Werror -D_WIN32 \
    -I tests/native/windows -I source/backend/native/include \
    "$work/meta_main.cpp" "$work/meta_other.cpp" -o "$work/meta-horror-header"
  "$work/meta-horror-header"
else
  echo "skip meta_horror header ($CXX unavailable)"
fi

# --- GDI / HPPD payloads: full module compile + runtime API smoke ----------
# phoenix_gdi.cpp (Slushi payloads) plus the four HPPD translation units
# (common/heavy/light/death) are linked into one binary against the Win32
# test double. This proves every ported payload body links (renames correct)
# and that the phoenixHppd* trigger/stop/shutdown runtime works. The test
# double makes GetDC return NULL, so payloads exit at their first surface
# check, which still exercises the worker-thread machinery.
if command -v "$CXX" >/dev/null; then
  gdi_srcs="source/backend/native/src/phoenix_gdi.cpp source/backend/native/src/phoenix_gdi_hppd_common.cpp source/backend/native/src/phoenix_gdi_hppd_heavy.cpp source/backend/native/src/phoenix_gdi_hppd_light.cpp source/backend/native/src/phoenix_gdi_hppd_death.cpp"
  # -Wno-conversion-null: the real MSVC SDK accepts NULL for the WPARAM of
  # SendMessageTimeoutW; the test double types it as ULONG_PTR, which g++
  # flags. This is a test-double-only strictness difference, not a code issue.
  "$CXX" -std=c++11 -Wall -Wextra -Werror -Wno-conversion-null -D_WIN32 \
    -I tests/native/windows -I source/backend/native/include \
    tests/native/test_gdi_hppd.cpp $gdi_srcs -o "$work/gdi-hppd-test"
  "$work/gdi-hppd-test"
else
  echo "skip gdi hppd ($CXX unavailable)"
fi

# --- Desktop notification helpers: mod strings are data, not shell syntax ----
if command -v "$CXX" >/dev/null; then
  notif="$work/notif"
  mkdir -p "$notif"
  for name in notify-send osascript; do
    printf '#!/bin/sh\nprintf "%%s\\n" "$@" > "$CAPTURE/%s.args"\n' "$name" > "$notif/$name"
    chmod +x "$notif/$name"
  done
  "$CXX" -std=c++11 -Wall -Wextra -Werror -I source/utils/include \
    tests/native/test_desktop_notifications.cpp -o "$work/notif-test"
  PATH="$notif:$PATH" CAPTURE="$notif" "$work/notif-test"
  # Graceful failure: a failing or missing notify-send must not crash.
  printf '#!/bin/sh\nexit 1\n' > "$notif/notify-send"
  printf '#include "phoenix_desktop_dialog.h"\nint main() { return phoenixShowLinuxNotification("x", "y") ? 1 : 0; }\n' > "$work/notif_fail.cpp"
  "$CXX" -std=c++11 -I source/utils/include "$work/notif_fail.cpp" -o "$work/notif-fail"
  PATH="$notif:$PATH" CAPTURE="$notif" "$work/notif-fail"
  rm "$notif/notify-send"
  PATH="$notif:$PATH" CAPTURE="$notif" "$work/notif-fail"
else
  echo "skip desktop notifications ($CXX unavailable)"
fi

# --- Linux monitor refresh rate (ported from Troll Engine) -------------------
# phoenix_refresh_rate.cpp is a real translation unit (Xlib.h cannot be merged
# into hxcpp output), so it is linked here the same way hxcpp links it.
if command -v "$CXX" >/dev/null; then
  refresh_src=source/backend/native/src/phoenix_refresh_rate.cpp
  # Behaviour, including every failure path, against the Xlib/XRandR double.
  "$CXX" -std=c++11 -Wall -Wextra -Werror -D__linux__ -U__ANDROID__ \
    -I tests/native/x11 -I source/backend/native/include \
    tests/native/test_refresh_rate.cpp "$refresh_src" -o "$work/refresh-rate-test"
  "$work/refresh-rate-test"

  # Targets other than desktop Linux get a stub that needs no X11 at all, and
  # the declaration header must stay valid C with C linkage.
  printf '#include "phoenix_refresh_rate.h"\nint main(void) { return phoenixMonitorRefreshRate(); }\n' \
    > "$work/refresh_caller.c"
  "$CXX" -std=c++11 -Wall -Wextra -Werror -U__linux__ -I source/backend/native/include \
    -c "$refresh_src" -o "$work/refresh_stub.o"
  if command -v "$CC" >/dev/null; then
    "$CC" -std=gnu99 -Wall -Wextra -Werror -I source/backend/native/include \
      -c "$work/refresh_caller.c" -o "$work/refresh_caller.o"
    "$CXX" "$work/refresh_caller.o" "$work/refresh_stub.o" -o "$work/refresh-stub"
    "$work/refresh-stub"
  fi

  # With the real development headers installed (libx11-dev, libxrandr-dev),
  # also build and run against the real Xlib. Without an X server this reports
  # zero; with one it reports the actual rate.
  if printf '#include <X11/extensions/Xrandr.h>\n' | "$CXX" -x c++ -fsyntax-only - 2>/dev/null; then
    printf '#include "phoenix_refresh_rate.h"\n#include <stdio.h>\nint main(void) { int rate = phoenixMonitorRefreshRate(); printf("real Xlib refresh rate: %%d Hz\\n", rate); return rate >= 0 ? 0 : 1; }\n' \
      > "$work/refresh_real.cpp"
    "$CXX" -std=c++11 -Wall -Wextra -Werror -I source/backend/native/include \
      "$work/refresh_real.cpp" "$refresh_src" -lX11 -lXrandr -o "$work/refresh-real"
    "$work/refresh-real"
  else
    echo "skip real Xlib refresh rate build (X11/XRandR development headers not installed)"
  fi
else
  echo "skip refresh rate ($CXX unavailable)"
fi

# --- LuaJIT on Android API 21: bionic stdio shim -----------------------------
# hxluajit's prebuilt Android LuaJIT references stdin/stdout/stderr, which
# bionic only exports from API 23 on, so the API 21 link needs the shim in
# source/backend/native/src/phoenix_luajit_bionic_stdio.cpp.
#
# The shim is compiled against a *model* of bionic's <stdio.h> rather than the
# host one. That distinction is the whole point: glibc declares
# `stdin`/`stdout`/`stderr` as plain `extern FILE*` variables, while bionic
# makes them macros over `__sF` below API 23 (`#define stdin (&__sF[0])`).
# Compiling against glibc therefore accepted a shim that could never build on
# Android, and it is why this test passed while CI kept failing to link. The
# model reproduces both bionic branches plus the deprecated `__sF` tag.
#
# For each configuration the object must define exactly the expected symbols:
#   android, API 21  -> all three, each out of a distinct __sF slot;
#   android, API 23  -> none (bionic exports them itself);
#   android, API 21 + NO_LUAJIT_BIONIC_STDIO -> none (escape hatch);
#   any non-Android  -> none (the host libc owns the names).
if command -v "$CXX" >/dev/null && command -v nm >/dev/null; then
  luajit_stdio_src=source/backend/native/src/phoenix_luajit_bionic_stdio.cpp
  luajit_stdio_inc=source/backend/native/include
  bionic_model="$work/bionic-model"
  mkdir -p "$bionic_model"

  # Model of platform_bionic/libc/include/stdio.h. Kept as a single header so
  # the shim's `#include <stdio.h>` resolves to it via -I ordering.
  cat > "$bionic_model/stdio.h" <<'EOF'
/* Model of platform_bionic/libc/include/stdio.h (API 21 / API 23 branches). */
#ifndef PHOENIX_TEST_BIONIC_STDIO_H
#define PHOENIX_TEST_BIONIC_STDIO_H
#ifdef __cplusplus
#define PHOENIX_TEST_BEGIN_DECLS extern "C" {
#define PHOENIX_TEST_END_DECLS }
#else
#define PHOENIX_TEST_BEGIN_DECLS
#define PHOENIX_TEST_END_DECLS
#endif
typedef struct __sFILE FILE;
/* Stride the test uses for its stand-in __sF[]; keep in sync via
   PHOENIX_TEST_BIONIC_FILE_BYTES below. */
struct __sFILE { unsigned char _opaque[64]; };
/* 32-bit Android has a 32-bit off_t and a separate off64_t. */
#if !defined(__LP64__)
typedef long long off64_t;
typedef long off_t;
#else
typedef long off64_t;
typedef long off_t;
#endif
/* Bionic tags these declarations with __INTRODUCED_IN / __REMOVED_IN, which
   expand to clang's availability attribute. GCC has no such attribute for
   Android, so model it only under clang and keep the deprecation warning that
   the shim has to silence. */
#if defined(__clang__)
#define PHOENIX_TEST_INTRODUCED_IN(api) __attribute__((availability(android, introduced = api)))
#define PHOENIX_TEST_REMOVED_IN(api) __attribute__((availability(android, obsoleted = api)))
#else
#define PHOENIX_TEST_INTRODUCED_IN(api)
#define PHOENIX_TEST_REMOVED_IN(api) __attribute__((deprecated("Use stdin/stdout/stderr")))
#endif
PHOENIX_TEST_BEGIN_DECLS
#if defined(__ANDROID_API__) && __ANDROID_API__ >= 23
/* API 23+: real variables... still macros, as bionic does for C/C++. */
extern FILE* stdin PHOENIX_TEST_INTRODUCED_IN(23);
extern FILE* stdout PHOENIX_TEST_INTRODUCED_IN(23);
extern FILE* stderr PHOENIX_TEST_INTRODUCED_IN(23);
#define stdin stdin
#define stdout stdout
#define stderr stderr
#else
/* API < 23: only __sF exists, and the streams are macros over it. */
extern FILE __sF[] PHOENIX_TEST_REMOVED_IN(23);
#define stdin (&__sF[0])
#define stdout (&__sF[1])
#define stderr (&__sF[2])
#endif
/* fseeko/ftello exist from API 1; the 64-bit spellings only from API 24. */
int fseeko(FILE*, off_t, int);
off_t ftello(FILE*);
int fseeko64(FILE*, off64_t, int);
off64_t ftello64(FILE*);
PHOENIX_TEST_END_DECLS
#endif
EOF

  # $1 = extra flags, $2 = output object. Always passes the bionic model first
  # on the include path so <stdio.h> resolves to it.
  luajit_stdio_build() {
    "$CXX" -std=c++11 -Wall -Wextra -Werror $1 \
      -I "$bionic_model" -I "$luajit_stdio_inc" \
      -c "$luajit_stdio_src" -o "$2"
  }

  luajit_stdio_build "-D__ANDROID__ -D__ANDROID_API__=21" "$work/luajit-stdio-android.o"
  luajit_stdio_build "-D__ANDROID__ -D__ANDROID_API__=23" "$work/luajit-stdio-api23.o"
  luajit_stdio_build "-D__ANDROID__ -D__ANDROID_API__=21 -DNO_LUAJIT_BIONIC_STDIO" \
    "$work/luajit-stdio-optout.o"
  # The non-Android case keeps the *host* <stdio.h>, i.e. a libc that owns the
  # stream symbols, which is what desktop/iOS/web builds see.
  "$CXX" -std=c++11 -Wall -Wextra -Werror \
    -I "$luajit_stdio_inc" -c "$luajit_stdio_src" -o "$work/luajit-stdio-other.o"

  # Each stream must come from its own __sF slot: stdin +0, stdout
  # +sizeof(FILE), stderr +2*sizeof(FILE). Checking the relocations proves the
  # shim points at bionic's array instead of a private FILE.
  if command -v objdump >/dev/null; then
    luajit_reloc=$(objdump -r "$work/luajit-stdio-android.o" | grep '__sF' || true)
    slots=$(printf '%s\n' "$luajit_reloc" | sed 's/.*__sF\(+0x[0-9a-f]*\)\{0,1\}.*/\1/' | sort -u | wc -l)
    [ "$slots" -eq 3 ] || {
      echo "FAIL: expected 3 distinct __sF slots in the shim, got $slots" >&2
      printf '%s\n' "$luajit_reloc" >&2
      exit 1
    }
  fi

  # Rename the three streams in the Android object before linking it, so the
  # test keeps using the host libc's stdin/stdout/stderr for its own output.
  linked_flags=""
  if command -v objcopy >/dev/null; then
    cp "$work/luajit-stdio-android.o" "$work/luajit-stdio-renamed.o"
    objcopy --redefine-sym stdin=phoenix_test_shim_stdin \
      --redefine-sym stdout=phoenix_test_shim_stdout \
      --redefine-sym stderr=phoenix_test_shim_stderr \
      "$work/luajit-stdio-renamed.o"
    linked_flags="-DPHOENIX_TEST_SHIM_LINKED"
  fi

  "$CXX" -std=c++11 -Wall -Wextra -Werror -I "$luajit_stdio_inc" $linked_flags \
    -DPHOENIX_TEST_SHIM_OBJECT="\"$work/luajit-stdio-android.o\"" \
    -DPHOENIX_TEST_SHIM_SOURCE="\"$root/$luajit_stdio_src\"" \
    -DPHOENIX_TEST_INCLUDE_DIR="\"$root/$luajit_stdio_inc\"" \
    -DPHOENIX_TEST_BIONIC_MODEL="\"$bionic_model\"" \
    -DPHOENIX_TEST_BIONIC_FILE_BYTES=64 \
    tests/native/test_luajit_bionic_stdio.cpp "$work/luajit-stdio-renamed.o" \
    -o "$work/luajit-stdio-test"
  "$work/luajit-stdio-test"

  # Everything else must define nothing, or the desktop/web links and API 23+
  # Android would get a second set of streams.
  for variant in api23 optout other; do
    "$CXX" -std=c++11 -Wall -Wextra -Werror -I "$luajit_stdio_inc" \
      -DPHOENIX_TEST_SHIM_OBJECT="\"$work/luajit-stdio-$variant.o\"" \
      -DPHOENIX_TEST_SHIM_SOURCE="\"$root/$luajit_stdio_src\"" \
      -DPHOENIX_TEST_INCLUDE_DIR="\"$root/$luajit_stdio_inc\"" \
      -DPHOENIX_TEST_BIONIC_MODEL="\"$bionic_model\"" \
      -DPHOENIX_TEST_BIONIC_FILE_BYTES=64 \
      tests/native/test_luajit_bionic_stdio.cpp "$work/luajit-stdio-$variant.o" \
      -o "$work/luajit-stdio-$variant-test"
    "$work/luajit-stdio-$variant-test" --expect-none
  done
  echo "bionic stdio shim smoke passed"
else
  echo "skip bionic stdio shim ($CXX or nm unavailable)"
fi

# Optional: compile the real header against the actual Windows SDK.
if [ -n "${PHOENIX_WINDOWS_CXX:-}" ]; then
  for i in 0 1; do
    # shellcheck disable=SC2086
    $PHOENIX_WINDOWS_CXX -std=c++11 -Wall -Wextra -Werror \
      -I source/backend/native/include -x c++ -c source/backend/native/include/phoenix_window.h \
      -o "$work/window$i.obj"
  done
  echo "phoenix_window real-SDK compile passed"
fi
