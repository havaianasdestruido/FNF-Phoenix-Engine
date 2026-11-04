#!/usr/bin/env bash
# Standalone C/C++ smoke tests for the native diagnostic headers and the
# Windows window-lookup helper. No Haxe/Lime/Android dependencies.
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
