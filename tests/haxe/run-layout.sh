#!/usr/bin/env bash
# Isolate dependency-free production modules from source/import.hx's
# Flixel/OpenFL imports; these tests run without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/mobile/flixel"
cp source/backend/ScreenLayout.hx "$test_source/backend/ScreenLayout.hx"
cp source/backend/ModSecurity.hx "$test_source/backend/ModSecurity.hx"
cp source/backend/ScriptSecurityScanner.hx "$test_source/backend/ScriptSecurityScanner.hx"
cp source/mobile/flixel/HitboxTouchLogic.hx "$test_source/mobile/flixel/HitboxTouchLogic.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main LayoutSpec --interp
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ModSecuritySpec --interp
