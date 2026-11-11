#!/bin/sh
# Phoenix Engine - iOS release build. Port of build-windows.bat; keep the
# three variants in sync (build-windows.bat / build-ios.sh / build-ios.ps1).
#
# Modding level 2 (Lua + Python) is the default for every native target in
# project.hxp, iOS included: hxluajit ships prebuilt LuaJIT for the simulator
# and for devices. Extra arguments are passed through to Lime, e.g.
# `./build/build-ios.sh -DMODDING_LEVEL=1`.
#
# Needs macOS with Xcode (`haxelib run lime setup ios` for the provisioning
# settings). The generated project is build/release/ios/; open it in Xcode to
# sign and install.
set -e
cd "$(dirname "$0")/.." || exit 1

echo "[Phoenix Engine] Building iOS (Release)..."
haxelib run lime build ios -release "$@"
echo
echo "[Phoenix Engine] Done. Xcode project: build/release/ios"
