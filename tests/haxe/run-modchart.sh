#!/usr/bin/env bash
# Exercise the renderer-free modchart core without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/modchart"
cp -r source/modchart/. "$test_source/modchart/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ModchartSpec --interp
