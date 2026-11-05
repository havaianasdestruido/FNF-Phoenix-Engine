#!/usr/bin/env bash
# Real hxcpp cache/invalidation smoke test (opt in; needs Haxe + a C++ toolchain
# and the pinned hxcpp fork installed). Ported from the former Python harness.
#
#   PHOENIX_RUN_HXCPP_CACHE_TESTS=1 bash tests/haxe/run-hxcpp-cache.sh
#
# The fixture uses a temporary copy of the engine's real native build.xml and
# header; it never edits the checkout or the user's regular object cache.
set -euo pipefail
cd "$(dirname "$0")/../.."
ROOT="$PWD"

if [ "${PHOENIX_RUN_HXCPP_CACHE_TESTS:-}" != "1" ]; then
  echo "skip: set PHOENIX_RUN_HXCPP_CACHE_TESTS=1 to run the native hxcpp cache smoke test"
  exit 0
fi
command -v haxe >/dev/null || { echo "haxe is required for the opted-in hxcpp cache test" >&2; exit 1; }

# A space in the path exercises cache paths that need quoting.
base=$(mktemp -d)
trap 'rm -rf "$base"' EXIT
root="$base/phoenix cache test"
mkdir -p "$root"
source_dir="$root/source/backend"
native="$source_dir/native"
include="$native/include"
mkdir -p "$include"
cp "$ROOT/source/backend/NativeHardware.hx" "$source_dir/"

# Keep the real dependency declaration and add a test-only C++ flag. Toggling it
# must not reuse an object built with other flags.
awk '{
  print
  if ($0 ~ /<files id="haxe">/)
    print "    <compilerflag value=\"-DPHOENIX_CACHE_PROBE_FLAG\" if=\"PHOENIX_CACHE_PROBE_FLAG\" />"
}' "$ROOT/source/backend/native/build.xml" > "$native/build.xml"

header="$include/phoenix_hardware.h"
original_header=$(cat "$ROOT/source/backend/native/include/phoenix_hardware.h")

write_header() {
  local marker="$1"
  {
    printf '%s\n' "$original_header"
    cat <<EOF

#include <stdio.h>
#ifdef PHOENIX_CACHE_PROBE_FLAG
#define PHOENIX_PROBE_SUFFIX "-flag"
#else
#define PHOENIX_PROBE_SUFFIX ""
#endif
#undef phoenixOsName
#define phoenixOsName(out, cap) (snprintf((out), (cap), "%s", "$marker" PHOENIX_PROBE_SUFFIX), 1)
EOF
  } > "$header"
}

cat > "$root/CacheProbe.hx" <<'EOF'
class CacheProbe {
  static function main() {
    Sys.println(backend.NativeHardware.osName());
  }
}
EOF

output="$root/build/release/smoke/obj"
if [ "${OS:-}" = "Windows_NT" ]; then exe="$output/CacheProbe.exe"; obj_ext="*.obj"; else exe="$output/CacheProbe"; obj_ext="*.o"; fi
export HXCPP_COMPILE_CACHE="$root/object cache"
export HXCPP_COMPILE_THREADS=4
export HXCPP_CACHE_MB=2048

build_log="$base/build.log"
build() {
  ( cd "$root" && haxe -cp source -cp . -main CacheProbe -cpp "$output" "$@" ) >"$build_log" 2>&1 \
    || { cat "$build_log" >&2; echo "haxe build failed" >&2; exit 1; }
}
run() { "$exe"; }
assert_contains() { grep -qF "$1" "$build_log" || { echo "expected '$1' in build output" >&2; cat "$build_log" >&2; exit 1; }; }
assert_not_contains() { if grep -qF "$1" "$build_log"; then echo "did not expect '$1' in build output" >&2; cat "$build_log" >&2; exit 1; fi; }
assert_run() { local got; got=$(run); [ "$got" = "$1" ] || { echo "expected probe output '$1', got '$got'" >&2; exit 1; }; }

# Cold build compiles the native group and populates the content-addressed cache.
write_header "cache-one"
build
assert_contains "Compiling group: haxe"
assert_run "cache-one"
find "$root/object cache" -name "$obj_ext" | grep -q . || { echo "object cache was not populated" >&2; exit 1; }

# A clean removes generated C++/binary output but not the cache; nothing recompiles.
rm -rf "$root/build"
build
assert_not_contains "Compiling group:"
assert_run "cache-one"

# Preserve the header's old mtime: the declared dependency must be hashed by
# content, not merely detected by filesystem timestamps.
timestamp=$(stat -c %Y "$header" 2>/dev/null || stat -f %m "$header")
write_header "cache-two"
touch -d "@$timestamp" "$header" 2>/dev/null || touch -t "$(date -r "$timestamp" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$timestamp" +%Y%m%d%H%M.%S)" "$header"
rm -rf "$root/build"
build
assert_contains "Compiling group: haxe"
assert_run "cache-two"
generated_cpp="$output/src/backend/NativeHardware.cpp"
cp "$generated_cpp" "$base/generated-cpp-reference"

# A flag change must invalidate the object even though the generated C++ is identical.
rm -rf "$root/build"
build -D PHOENIX_CACHE_PROBE_FLAG
cmp -s "$generated_cpp" "$base/generated-cpp-reference" || { echo "generated C++ changed unexpectedly" >&2; exit 1; }
assert_contains "Compiling group: haxe"
assert_run "cache-two-flag"

echo "hxcpp cache smoke passed"
