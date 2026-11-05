#!/usr/bin/env bash
# Isolate the alphabet font model from source/import.hx's Flixel/OpenFL imports;
# these tests run without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/objects" "$test_source/backend"
cp source/objects/AlphabetFont.hx "$test_source/objects/AlphabetFont.hx"
cp tests/haxe/stubs/backend/ClientPrefs.hx "$test_source/backend/ClientPrefs.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main AlphabetFontSpec --interp
