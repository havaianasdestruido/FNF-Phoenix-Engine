#!/usr/bin/env bash
# Exercise the Mic'd Up! health-icon style resolution without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/IconStyle.hx "$test_source/backend/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main IconStyleSpec --interp
