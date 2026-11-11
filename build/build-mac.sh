#!/bin/sh
# Phoenix Engine - macOS release build. Port of build-windows.bat; keep the
# three variants in sync (build-windows.bat / build-mac.sh / build-mac.ps1).
#
# Modding level 2 (Lua + Python) is the default for every native target in
# project.hxp, so -DMODDING_LEVEL is not needed: a plain `lime build mac`
# already includes both script languages. Extra arguments are passed through
# to Lime, e.g. `./build/build-mac.sh -DMODDING_LEVEL=1`.
set -e
cd "$(dirname "$0")/.." || exit 1

echo "[Phoenix Engine] Building macOS (Release)..."
haxelib run lime build mac -release "$@"
echo
echo "[Phoenix Engine] Done. Output: build/release/mac/bin"
