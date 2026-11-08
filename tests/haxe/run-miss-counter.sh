#!/usr/bin/env bash
# Exercise the production miss-popup model without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/play/objects"
cp source/play/objects/MissCounter.hx "$test_source/play/objects/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main MissCounterSpec --interp
