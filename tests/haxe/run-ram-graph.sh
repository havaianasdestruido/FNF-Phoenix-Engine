#!/usr/bin/env bash
# Run the graph's data/geometry tests without the game's OpenFL dependencies.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/debug"
cp source/debug/RamGraphHistory.hx "$test_source/debug/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main RamGraphHistorySpec --interp
