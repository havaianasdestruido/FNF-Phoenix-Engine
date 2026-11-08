#!/usr/bin/env bash
# Settings rows are laid out by backend.MenuLayout, which is deliberately free of
# Flixel/OpenFL imports so it runs on the Haxe interpreter without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/MenuLayout.hx "$test_source/backend/MenuLayout.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main MenuLayoutSpec --interp
