#!/usr/bin/env bash
# Exercise the Mic'd Up! Early/Late classification without game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/play/helpers"
cp source/play/helpers/HitTiming.hx "$test_source/play/helpers/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main HitTimingSpec --interp
