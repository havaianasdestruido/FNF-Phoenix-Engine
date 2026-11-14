#!/usr/bin/env bash
# Options -> Audio -> Master Volume and the sound tray share one curve.
#
# `backend/VolumeCurve.hx` is deliberately free of Flixel/OpenFL/Lime imports,
# so the mapping (and the numbers the tray has always drawn) runs with nothing
# but Haxe.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/VolumeCurve.hx "$test_source/backend/VolumeCurve.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main VolumeCurveSpec --interp
