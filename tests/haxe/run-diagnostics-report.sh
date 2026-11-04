#!/usr/bin/env bash
# Exercise backend/DiagnosticsReport.hx in the Haxe interpreter. The reporter
# is deliberately Flixel/Sys-free (the collection of the facts lives in
# backend/Diagnostics.hx), so no game haxelibs or stubs are needed.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/DiagnosticsReport.hx "$test_source/backend/DiagnosticsReport.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main DiagnosticsReportSpec --interp
