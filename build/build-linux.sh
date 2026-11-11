#!/bin/sh
# Phoenix Engine - Linux release build. Port of build-windows.bat; keep the
# three variants in sync (build-windows.bat / build-linux.sh / build-linux.ps1).
#
# Modding level 2 (Lua + Python) is the default for every native target in
# project.hxp, so -DMODDING_LEVEL is not needed: a plain `lime build linux`
# already includes both script languages. Extra arguments are passed through
# to Lime, e.g. `./build/build-linux.sh -DMODDING_LEVEL=1`.
set -e
cd "$(dirname "$0")/.." || exit 1

echo "[Phoenix Engine] Building Linux (Release)..."
haxelib run lime build linux -release "$@"
echo
echo "[Phoenix Engine] Done. Output: build/release/linux/bin"
