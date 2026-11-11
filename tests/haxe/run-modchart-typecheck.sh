#!/usr/bin/env bash
# Typecheck + exercise the modchart runtime adapter and script callbacks
# against renderer-free stubs (no game haxelibs needed).
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/modchart" "$test_source/play/helpers" "$test_source/psychlua/callbacks" "$test_source/psychlua/pystdlib"
cp -r source/modchart/. "$test_source/modchart/"
cp source/play/helpers/PlayStateModchart.hx "$test_source/play/helpers/"
cp source/psychlua/callbacks/ModchartCallbacks.hx "$test_source/psychlua/callbacks/"
cp source/psychlua/pystdlib/PyModchartLib.hx "$test_source/psychlua/pystdlib/"
cp -r tests/haxe/stubs/modchart/. "$test_source/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ModchartRuntimeSpec --interp
