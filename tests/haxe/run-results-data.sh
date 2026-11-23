#!/usr/bin/env bash
# Exercise states/ResultsData.hx in the Haxe interpreter. The results snapshot
# only needs a difficulty table and a data-carrying PlayState, so no game
# haxelibs are required. Run with: bash tests/haxe/run-results-data.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/states" "$test_source/backend" "$test_source/play"
cp source/states/ResultsData.hx "$test_source/states/ResultsData.hx"
cp tests/haxe/stubs/results-data/backend/CoolUtil.hx "$test_source/backend/CoolUtil.hx"
cp tests/haxe/stubs/results-data/play/PlayState.hx "$test_source/play/PlayState.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ResultsDataSpec --interp
