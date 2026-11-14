#!/usr/bin/env bash
# Hold-to-confirm state machine and enlarged touch-target geometry.
# Dependency-free: the production logic module has no game haxelib imports.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/HoldToConfirmLogic.hx "$test_source/backend/HoldToConfirmLogic.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main HoldToConfirmSpec --interp

# The game is built as C++, a static target, where a required Float cannot be
# compared with null. The interpreter above is a dynamic target and accepts
# that, so the same module is also typechecked for C++ (nothing is generated).
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main HoldToConfirmSpec -cpp "$test_source/cpp" --no-output

# The state machine was always right; the bug was in what callers fed it.
# `controls.ACCEPT` only lives for one frame (JUST_PRESSED), so a guard wired
# to it drew one frame of bar and then cancelled forever. Scan the guarded
# call sites for just-pressed flags - this needs the real source tree.
"${HAXE:-haxe}" -cp tests/haxe -main HoldToConfirmCallSitesSpec --interp
