#!/usr/bin/env bash
# Typecheck and exercise the Modchart Lab editor state
# (editors/ModchartLabState) against renderer-free stubs, without game
# haxelibs. Run by .github/workflows/checks.yml.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/modchart" "$test_source/editors"
cp -r source/modchart/. "$test_source/modchart/"
cp source/editors/ModchartLabState.hx "$test_source/editors/"
cp -r tests/haxe/stubs/lab/. "$test_source/"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main ModchartLabStateSpec --interp
