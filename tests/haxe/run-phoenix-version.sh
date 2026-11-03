#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/PhoenixVersion.hx source/backend/PhoenixReleases.hx "$test_source/backend/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main PhoenixVersionSpec --interp
