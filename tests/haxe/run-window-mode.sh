#!/usr/bin/env bash
# Window display mode (Windowed / Borderless / Fullscreen): normalization,
# persistence, the F11 toggle and the windowed-only interactions, without the
# full Flixel/Lime dependency tree.
#
# Behaviour runs twice under the interpreter: with no target define (the
# non-desktop no-op path) and with `-D desktop` (the native window behaviour).
# The desktop-only resize branch is then typechecked (and its C++ inspected) for
# each native desktop target without invoking hxcpp or producing binaries.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/WindowMode.hx "$test_source/backend/"

spec() {
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe/stubs/window-mode -cp tests/haxe -main WindowModeSpec "$@"
}

# No target define: the sys/interpreter run exercises normalization, the
# preference flags and the non-desktop resize no-op.
spec --interp
# `-D desktop` exercises the native window path (apply, F11, resize).
spec -D desktop --interp

for platform in windows linux mac; do
  output="$test_source/generated/$platform"
  spec -D desktop -D "$platform" -D no-compilation -cpp "$output"
  generated="$output/src/backend/WindowMode.cpp"
  grep -Fq 'resizeWindow' "$generated"
done
