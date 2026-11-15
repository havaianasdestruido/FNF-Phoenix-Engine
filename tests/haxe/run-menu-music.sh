#!/usr/bin/env bash
# Menu music volume / fade rules (backend/MenuMusicLogic).
# Dependency-free: the logic module has no game haxelib imports, so the spec
# runs on the Haxe interpreter without Flixel/OpenFL/Lime installed.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/MenuMusicLogic.hx "$test_source/backend/MenuMusicLogic.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main MenuMusicSpec --interp
