#!/usr/bin/env bash
# Test the finite-number guard and verify Lua tween callbacks reject unsafe values.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/psychlua/callbacks"
cp source/psychlua/TweenValueValidation.hx "$test_source/psychlua/"
cp source/psychlua/callbacks/TweenCallbacks.hx "$test_source/psychlua/callbacks/"
cp -R tests/haxe/stubs/tween-callbacks/. "$test_source/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main TweenValueValidationSpec --interp
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main TweenCallbacksSpec --interp
