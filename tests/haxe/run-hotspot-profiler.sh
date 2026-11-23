#!/usr/bin/env bash
# Exercise debug/profiler/HotspotProfiler.hx in the Haxe interpreter with a
# scripted stand-in for the Flixel-heavy FrameProfiler. Run with:
#   bash tests/haxe/run-hotspot-profiler.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/debug/profiler"
cp source/debug/profiler/HotspotProfiler.hx "$test_source/debug/profiler/HotspotProfiler.hx"
cp tests/haxe/stubs/hotspot-profiler/debug/FrameProfiler.hx "$test_source/debug/FrameProfiler.hx"
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main HotspotProfilerSpec --interp
