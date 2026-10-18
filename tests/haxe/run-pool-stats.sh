#!/usr/bin/env bash
# Isolate the pooled-sprite accounting module from source/import.hx's Flixel/OpenFL
# imports; the accounting is intentionally dependency free so it can be executed
# without the game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/debug"
cp source/debug/PoolStats.hx "$test_source/debug/PoolStats.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main PoolStatsSpec --interp
