#!/bin/sh
# Phoenix Engine - Android release build. Port of build-windows.bat; keep the
# three variants in sync (build-windows.bat / build-android.sh /
# build-android.ps1).
#
# Modding level 2 (Lua + Python) is the default for every native target in
# project.hxp, mobile included: hxluajit ships prebuilt LuaJIT for
# armv7/x86/arm64/x86_64, so `lime build android` includes Lua and Python
# without any flag. Extra arguments are passed through to Lime, e.g.
# `./build/build-android.sh -DMODDING_LEVEL=1`.
#
# Needs ANDROID_SDK / ANDROID_NDK_ROOT configured (`haxelib run lime setup
# android`). CI uses .github/workflows/main.yml instead.
set -e
cd "$(dirname "$0")/.." || exit 1

echo "[Phoenix Engine] Building Android (Release)..."
haxelib run lime build android -release "$@"
echo
echo "[Phoenix Engine] Done. APK: build/release/android/bin/app/build/outputs/apk"
