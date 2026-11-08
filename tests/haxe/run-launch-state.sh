#!/usr/bin/env bash
# Isolate the launch flag model from source/import.hx's Flixel/OpenFL imports;
# this test runs without the game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/LaunchState.hx source/backend/LaunchTarget.hx "$test_source/backend/"

# Plain build: no launch flags, the splash/title flow stays the default.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main LaunchStateSpec --interp

# One compile per flag, so the `#if` wiring is checked against real defines.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main LaunchStateDefineSpec -D FREEPLAY --interp
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main LaunchStateDefineSpec -D MENU --interp
