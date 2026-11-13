#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/AndroidTVPolicy.hx "$test_source/backend/AndroidTVPolicy.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main AndroidTVPolicySpec --interp
