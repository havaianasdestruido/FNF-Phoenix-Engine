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
