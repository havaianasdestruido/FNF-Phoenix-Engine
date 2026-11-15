#!/usr/bin/env bash
# Exercise the real metronome policy and shared sound lifecycle without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -r tests/haxe/stubs/metronome/. "$test_source/"
mkdir -p "$test_source/backend" "$test_source/play/helpers"
cp source/backend/Metronome.hx "$test_source/backend/"
cp source/play/helpers/PlayStateMetronome.hx "$test_source/play/helpers/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D FLX_PITCH -main MetronomeSpec --interp
# Static targets must compile the same helper and nullable seek deadline.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D FLX_PITCH -main MetronomeSpec -cpp "$test_source/cpp" --no-output
# Flash/AIR have no FLX_PITCH; the shared voice still has to typecheck.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main MetronomeSpec --swf "$test_source/spec.swf" --no-output
