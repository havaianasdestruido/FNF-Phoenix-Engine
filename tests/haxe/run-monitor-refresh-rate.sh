#!/usr/bin/env bash
# Monitor refresh rate helper (Linux X11 query ported from Troll Engine), without
# the Flixel/Lime dependency tree: behaviour under the interpreter, then the
# generated C++ per target, without invoking hxcpp or producing binaries.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/MonitorRefreshRate.hx "$test_source/backend/"
common=(-cp "$test_source" -cp tests/haxe/stubs/refresh-rate -cp tests/haxe -main MonitorRefreshRateSpec)

"${HAXE:-haxe}" "${common[@]}" --interp

# Desktop Linux must call the native query and pull in its build file; every
# other target (Android included, which is also Linux) must not reference it.
for platform in linux windows mac android; do
  output="$test_source/generated/$platform/linux/obj"
  defines=(-D "$platform")
  if [ "$platform" = android ]; then defines+=(-D linux); fi
  "${HAXE:-haxe}" "${common[@]}" "${defines[@]}" -D no-compilation -cpp "$output"
  generated="$output/src/backend/MonitorRefreshRate.cpp"
  if [ "$platform" = linux ]; then
    grep -Fq 'phoenixMonitorRefreshRate()' "$generated"
    grep -Fq '#include "phoenix_refresh_rate.h"' "$generated"
    grep -Fq 'source/backend/native/refresh_rate_build.xml' "$output/Build.xml"
  else
    if grep -rFq 'phoenixMonitorRefreshRate' "$output/src" "$output/include"; then
      echo "native refresh rate query leaked into the $platform build" >&2
      exit 1
    fi
    if grep -Fq 'refresh_rate_build.xml' "$output/Build.xml"; then
      echo "refresh rate build file leaked into the $platform build" >&2
      exit 1
    fi
  fi
done
