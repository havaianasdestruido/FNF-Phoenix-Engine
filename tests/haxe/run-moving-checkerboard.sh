#!/usr/bin/env bash
set -euo pipefail

# Typecheck and execute the production FlxBackdrop wrapper without installing
# Lime/OpenFL/Flixel. Only the renderer surface it uses is stubbed.
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/objects" "$work/backend"
cp "$root/source/objects/MovingCheckerboard.hx" "$work/objects/MovingCheckerboard.hx"
cp "$root/source/backend/MenuCheckerTextures.hx" "$work/backend/MenuCheckerTextures.hx"
cp -R "$root/tests/haxe/stubs/moving-checkerboard/." "$work/"

"${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -main MovingCheckerboardSpec --interp
