#!/usr/bin/env bash
# Exercise backend/CoolUtil.hx in the Haxe interpreter with stubbed Flixel /
# Lime surfaces. Run with: bash tests/haxe/run-cool-util.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/data" "$test_source/objects" "$test_source/play" "$test_source/utils"
cp source/backend/CoolUtil.hx "$test_source/backend/CoolUtil.hx"
cp source/backend/Conductor.hx "$test_source/backend/Conductor.hx"
cp source/backend/PhoenixVersion.hx "$test_source/backend/PhoenixVersion.hx"
cp tests/haxe/stubs/cool-util/import.hx "$test_source/import.hx"
cp tests/haxe/stubs/cool-util/Main.hx "$test_source/Main.hx"
cp -r tests/haxe/stubs/cool-util/backend/. "$test_source/backend/"
cp -r tests/haxe/stubs/cool-util/flixel "$test_source/flixel"
cp -r tests/haxe/stubs/cool-util/objects/. "$test_source/objects/"
cp -r tests/haxe/stubs/cool-util/shaders "$test_source/shaders"
cp -r tests/haxe/stubs/cool-util/lime "$test_source/lime"
cp -r tests/haxe/stubs/cool-util/openfl "$test_source/openfl"
cp tests/haxe/stubs/cool-util/utils/CoolSystemStuff.hx "$test_source/utils/CoolSystemStuff.hx"
cp tests/haxe/stubs/backend/ClientPrefs.hx "$test_source/backend/ClientPrefs.hx"
cp tests/haxe/stubs/data/Song.hx "$test_source/data/Song.hx"
cp tests/haxe/stubs/data/Section.hx "$test_source/data/Section.hx"
cp tests/haxe/stubs/objects/Note.hx "$test_source/objects/Note.hx"
cp tests/haxe/stubs/objects/NoteSplash.hx "$test_source/objects/NoteSplash.hx"
cp tests/haxe/stubs/play/PlayState.hx "$test_source/play/PlayState.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main CoolUtilSpec --interp
