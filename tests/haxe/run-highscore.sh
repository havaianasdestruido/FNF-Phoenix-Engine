#!/usr/bin/env bash
# Exercise backend/Highscore.hx in the Haxe interpreter. The save store only
# needs a FlxG.save stand-in, a path formatter and the difficulty table, so no
# game haxelibs are required. Run with: bash tests/haxe/run-highscore.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/data" "$test_source/flixel"
cp source/backend/Highscore.hx "$test_source/backend/Highscore.hx"
cp tests/haxe/stubs/highscore/import.hx "$test_source/import.hx"
cp tests/haxe/stubs/highscore/backend/Paths.hx "$test_source/backend/Paths.hx"
cp tests/haxe/stubs/highscore/backend/CoolUtil.hx "$test_source/backend/CoolUtil.hx"
cp tests/haxe/stubs/highscore/flixel/FlxG.hx "$test_source/flixel/FlxG.hx"
cp tests/haxe/stubs/data/Song.hx "$test_source/data/Song.hx"
cp tests/haxe/stubs/data/Section.hx "$test_source/data/Section.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main HighscoreSpec --interp
