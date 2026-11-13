#!/usr/bin/env bash
# Typecheck and exercise the Flixel hold-to-confirm layer with renderer-free
# stubs (no game haxelibs required). FLX_TOUCH is defined so the touch branch
# of TouchTarget.sample() is compiled too.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -r tests/haxe/stubs/hold-confirm/. "$test_source/"
mkdir -p "$test_source/backend" "$test_source/objects"
cp source/backend/HoldToConfirmLogic.hx "$test_source/backend/HoldToConfirmLogic.hx"
cp source/objects/TouchTarget.hx "$test_source/objects/TouchTarget.hx"
cp source/objects/HoldToConfirm.hx "$test_source/objects/HoldToConfirm.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D FLX_TOUCH \
  -main HoldToConfirmTypecheck --interp
