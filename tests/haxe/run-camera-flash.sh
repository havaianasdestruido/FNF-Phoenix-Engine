#!/usr/bin/env bash
# Exercise the flash policy without requiring Flixel/OpenFL libraries.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -R tests/haxe/flash-stubs/. "$test_source/"
cp source/backend/CameraFlash.hx "$test_source/backend/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main CameraFlashSpec --interp
