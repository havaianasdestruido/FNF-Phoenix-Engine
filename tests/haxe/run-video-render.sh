#!/usr/bin/env bash
# Rendering Mode folders and FFmpeg lookup.
#
# Guards the two Windows-only failures behind "rendering does nothing / no
# folder appears": `FileSystem.createDirectory()` does not create missing
# parents (`CreateDirectory` on Windows), and relative render paths were taken
# from a working directory that is not necessarily the game's folder. Also
# checks that FFmpeg is found next to the game, on PATH, in the usual
# package-manager folders and through PHOENIX_FFMPEG, instead of only in the
# working directory.
#
# backend/RenderPaths.hx and backend/FFmpegLocator.hx are free of Flixel/Lime
# imports, so this runs with nothing but Haxe.
set -euo pipefail
repo_root=$(cd "$(dirname "$0")/../.." && pwd)
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/work"
cp "$repo_root/source/backend/RenderPaths.hx" "$test_source/backend/"
cp "$repo_root/source/backend/FFmpegLocator.hx" "$test_source/backend/"
cd "$test_source/work"
"${HAXE:-haxe}" -cp "$test_source" -cp "$repo_root/tests/haxe" -main VideoRenderSpec --interp
