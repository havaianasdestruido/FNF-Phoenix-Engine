#!/usr/bin/env bash
# The Distant Note warp is plain math in shaders.DistantNoteWarp, kept free of
# Flixel/OpenFL imports so it runs on the Haxe interpreter without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/shaders"
cp source/shaders/DistantNoteWarp.hx "$test_source/shaders/DistantNoteWarp.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main DistantNoteWarpSpec --interp
