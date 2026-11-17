#!/usr/bin/env bash
# Hidden key code, scene layout and mesh numbers of the FlxClothSprite easter
# egg (backend/ClothEasterEggLogic).
# Dependency-free: the logic module has no game haxelib imports, so the spec
# runs on the Haxe interpreter without Flixel/OpenFL/Lime installed.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/ClothEasterEggLogic.hx "$test_source/backend/ClothEasterEggLogic.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ClothEasterEggSpec --interp

# The layout numbers are only right if the shipped art has the size they assume,
# and only ships if the compact-build allowlist lists it.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ClothAssetsSpec --interp
