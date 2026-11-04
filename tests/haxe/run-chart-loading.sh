#!/usr/bin/env bash
# Exercise the production data/Song.hx JSON normalizer without the game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -r tests/haxe/stubs/chart-loading/. "$test_source/"
mkdir -p "$test_source/data"
cp source/data/Song.hx "$test_source/data/Song.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ChartLoadingSpec --interp
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ChartLoadingSpec -js "$test_source/chart-loading.js"
node "$test_source/chart-loading.js"
