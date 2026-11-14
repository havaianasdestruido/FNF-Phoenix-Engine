#!/usr/bin/env bash
# Deterministic policy tests, real PlayState adapter against Flixel doubles,
# real splash helper paths, and wiring guards. No game haxelibs are required.
set -euo pipefail
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/policy/play/helpers" "$work/adapter/play/helpers" "$work/notes/play/helpers"
cp source/play/helpers/AdaptivePerformance.hx "$work/policy/play/helpers/"
"${HAXE:-haxe}" -cp "$work/policy" -cp tests/haxe -main AdaptivePerformanceSpec --interp

cp -r tests/haxe/stubs/adaptive-performance/. "$work/adapter/"
cp source/play/helpers/{AdaptivePerformance,PlayStateAdaptivePerformance}.hx "$work/adapter/play/helpers/"
"${HAXE:-haxe}" -cp "$work/adapter" -cp tests/haxe -main AdaptivePerformanceIntegrationSpec --interp
if command -v node >/dev/null 2>&1; then
  "${HAXE:-haxe}" -cp "$work/adapter" -cp tests/haxe -main AdaptivePerformanceIntegrationSpec -js "$work/browser.js"
  node "$work/browser.js"
else
  echo 'SKIP: browser GC fallback test (Node.js not found)'
fi

cp -r tests/haxe/stubs/adaptive-notes/. "$work/notes/"
cp source/play/helpers/PlayStateNoteHelpers.hx "$work/notes/play/helpers/"
"${HAXE:-haxe}" -cp "$work/notes" -cp tests/haxe -main AdaptivePerformanceNotesSpec --interp
"${HAXE:-haxe}" -cp tests/haxe -main AdaptivePerformanceWiringSpec --interp
