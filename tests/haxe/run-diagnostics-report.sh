#!/usr/bin/env bash
# Compile and run both halves of `phoenix://diagnostics` in the Haxe interpreter,
# against the small stubs in tests/haxe/stubs/diagnostics and without any game
# haxelibs:
#
#   backend/DiagnosticsReport.hx   assembles the text — seven sections, a bounded
#                                  log tail, one `unavailable:` row instead of a
#                                  crash, and nothing written to disk;
#   states/DiagnosticsState.hx     the page that renders, scrolls, copies and
#                                  refreshes it, and releases its camera on exit.
#
# It runs from a throwaway working directory on purpose: the report tails
# vlog/log.txt relative to the cwd, and a real log sitting next to the game must
# not leak into the expected output.
set -euo pipefail
cd "$(dirname "$0")/../.."
root=$(pwd)
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -r tests/haxe/stubs/diagnostics/. "$test_source/"
mkdir -p "$test_source/backend" "$test_source/states"
cp source/backend/DiagnosticsReport.hx "$test_source/backend/DiagnosticsReport.hx"
# LogUtils is Flixel-free on purpose, so the report sees the real redaction and
# size policy here instead of a paraphrase of it.
cp source/backend/LogUtils.hx "$test_source/backend/LogUtils.hx"
cp source/states/DiagnosticsState.hx "$test_source/states/DiagnosticsState.hx"
cd "$test_source"
"${HAXE:-haxe}" -cp "$test_source" -cp "$root/tests/haxe" -main DiagnosticsReportSpec --interp
"${HAXE:-haxe}" -cp "$test_source" -cp "$root/tests/haxe" -main DiagnosticsStateSpec --interp
