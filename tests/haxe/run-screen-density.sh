#!/usr/bin/env bash
# Exercise backend/ScreenDensity.hx in the Haxe interpreter against the real
# PlatformIcons module (it has no Lime/Flixel dependency); only `flixel.FlxG`
# is stubbed. Run with: bash tests/haxe/run-screen-density.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/flixel"
cp source/backend/ScreenDensity.hx "$test_source/backend/ScreenDensity.hx"
cp source/backend/PlatformIcons.hx "$test_source/backend/PlatformIcons.hx"
cp tests/haxe/stubs/screen-density/flixel/FlxG.hx "$test_source/flixel/FlxG.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ScreenDensitySpec --interp
