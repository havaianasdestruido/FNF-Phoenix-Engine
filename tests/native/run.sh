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
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# --- phoenix_system.h: compile as C and C++, two translation units -----------
cat > "$work/system_other.c" <<'EOF'
#include "phoenix_system.h"
double other(void) { return phoenixMonotonicSeconds(); }
EOF
cat > "$work/system_main.c" <<'EOF'
#include "phoenix_system.h"
#include "phoenix_system.h"
#include <assert.h>
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
for lang in c cpp; do
  if [ "$lang" = c ]; then comp="$CC"; std=gnu99; else comp="$CXX"; std=c++11; fi
  command -v "$comp" >/dev/null || { echo "skip system smoke ($comp unavailable)"; continue; }
  "$comp" "-std=$std" -Wall -Wextra -Werror -I source/debug/system/include \
    "$work/system_main.c" "$work/system_other.c" -o "$work/system_$lang"
  "$work/system_$lang"
done
echo "phoenix_system smoke passed"

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
# source/backend/native/src/phoenix_luajit_bionic_stdio.cpp. The translation
# unit is compiled here with the Android defines, its stream symbols are
# renamed (objcopy) so they cannot take over the host libc's, and the object is
# inspected: the Android build must define all three streams out of bionic's
# __sF array, every other build must define none of them.
if command -v "$CXX" >/dev/null && command -v nm >/dev/null; then
  luajit_stdio_src=source/backend/native/src/phoenix_luajit_bionic_stdio.cpp
  luajit_stdio_inc=source/backend/native/include

  "$CXX" -std=c++11 -Wall -Wextra -Werror -D__ANDROID__ -DLUA_ALLOWED \
    -I "$luajit_stdio_inc" -c "$luajit_stdio_src" -o "$work/luajit-stdio-android.o"
  # A future NDK may export the variables itself; the escape hatch must then
  # produce an object that defines nothing.
  "$CXX" -std=c++11 -Wall -Wextra -Werror -D__ANDROID__ -DLUA_ALLOWED \
    -DNO_LUAJIT_BIONIC_STDIO -I "$luajit_stdio_inc" \
    -c "$luajit_stdio_src" -o "$work/luajit-stdio-optout.o"
  "$CXX" -std=c++11 -Wall -Wextra -Werror \
    -I "$luajit_stdio_inc" -c "$luajit_stdio_src" -o "$work/luajit-stdio-other.o"

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
    tests/native/test_luajit_bionic_stdio.cpp "$work/luajit-stdio-renamed.o" \
    -o "$work/luajit-stdio-test"
  "$work/luajit-stdio-test"

  # Nothing may be defined outside Android+LUA_ALLOWED, or the desktop and
  # Emscripten links would get a second set of streams.
  for variant in other optout; do
    "$CXX" -std=c++11 -Wall -Wextra -Werror -I "$luajit_stdio_inc" \
      -DPHOENIX_TEST_SHIM_OBJECT="\"$work/luajit-stdio-$variant.o\"" \
      -DPHOENIX_TEST_SHIM_SOURCE="\"$root/$luajit_stdio_src\"" \
      -DPHOENIX_TEST_INCLUDE_DIR="\"$root/$luajit_stdio_inc\"" \
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
