#!/usr/bin/env bash
# Exercise the production gameplay chart loader with renderer-free stubs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -r tests/haxe/stubs/chart-loader/. "$test_source/"
mkdir -p "$test_source/play/helpers"
cp source/play/helpers/PlayStateChartLoader.hx "$test_source/play/helpers/PlayStateChartLoader.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ChartLoaderSpec --interp
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ChartLoaderSpec -js "$test_source/chart-loader.js"
node "$test_source/chart-loader.js"
