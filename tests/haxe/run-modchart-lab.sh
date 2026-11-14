#!/usr/bin/env bash
# Exercise the Modchart Lab core (catalog, automation, Lua/Python export)
# without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/modchart"
cp -r source/modchart/. "$test_source/modchart/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ModchartLabSpec --interp
