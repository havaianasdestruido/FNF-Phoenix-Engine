#!/usr/bin/env bash
# Hit-window presets (ClientPrefs.accuracyPreset), perfectWindow 15.0 ms default,
# and GamepadDeadzone clamping/wiring.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/AccuracyPresets.hx "$test_source/backend/AccuracyPresets.hx"
cp source/backend/GamepadDeadzone.hx "$test_source/backend/GamepadDeadzone.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main AccuracyPresetsSpec --interp
