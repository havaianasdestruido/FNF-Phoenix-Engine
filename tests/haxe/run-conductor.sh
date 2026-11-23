#!/usr/bin/env bash
# Exercise the production timing core (backend/Conductor.hx) in the Haxe
# interpreter. The module only needs Flixel-free stubs, so no game haxelibs are
# required. Run with: bash tests/haxe/run-conductor.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/data" "$test_source/objects" "$test_source/play"
cp source/backend/Conductor.hx "$test_source/backend/Conductor.hx"
cp tests/haxe/stubs/backend/ClientPrefs.hx "$test_source/backend/ClientPrefs.hx"
cp tests/haxe/stubs/data/Song.hx "$test_source/data/Song.hx"
cp tests/haxe/stubs/data/Section.hx "$test_source/data/Section.hx"
cp tests/haxe/stubs/objects/Note.hx "$test_source/objects/Note.hx"
cp tests/haxe/stubs/objects/NoteSplash.hx "$test_source/objects/NoteSplash.hx"
cp tests/haxe/stubs/play/PlayState.hx "$test_source/play/PlayState.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ConductorSpec --interp
