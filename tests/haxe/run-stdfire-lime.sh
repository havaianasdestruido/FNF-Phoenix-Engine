#!/usr/bin/env bash
# Real Lime/SDL + hxcpp smart-string regression. Linux only; requires the
# project's pinned Lime and hxcpp haxelibs and a C compiler. SDL's dummy video
# driver and a modal-call probe keep the test headless and non-interactive.
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/source/backend" "$work/source/utils" "$work/source/android/platform" "$work/source/ios/platform"
cp source/backend/StdFire.hx source/backend/LimeNativeText.hx "$work/source/backend/"
cp source/android/platform/AndroidStdFire.hx "$work/source/android/platform/"
cp source/ios/platform/IOSStdFire.hx "$work/source/ios/platform/"
cp tests/haxe/stubs/stdfire/utils/PlatformUtil.hx "$work/source/utils/"

# Check the actual Lime cache and JNI branches, without an Android/iOS SDK.
# This is typechecking, not a substitute for a mobile build or device test.
for platform in android ios; do
  "${HAXE:-haxe}" -cp "$work/source" -cp "$root/tests/haxe" -lib lime \
    -D "$platform" -D lime_cffi -D HX_SMART_STRINGS -main StdFireMobileTypecheck \
    -cpp "$work/typecheck-$platform" --no-output
done

lime_ndll=$(haxelib path lime | sed -n 's/^-L //p' | head -n 1)
if [[ ! -f "$lime_ndll/Linux64/lime.ndll" ]]; then
  echo "Pinned Lime Linux64 native library not found under $lime_ndll" >&2
  exit 1
fi
"${CC:-cc}" -std=c99 -Wall -Wextra -Werror -shared -fPIC \
  tests/native/stdfire_lime_alert_probe.c -o "$work/alert-probe.so"
"${HAXE:-haxe}" -cp "$work/source" -cp "$root/tests/haxe" -lib lime \
  -D lime_cffi -D desktop -D linux -D HX_SMART_STRINGS -main StdFireLimeSpec -cpp "$work/bin"
cp "$lime_ndll/Linux64/lime.ndll" "$work/bin/"
(
  cd "$work/bin"
  export PHOENIX_TEST_LIME_ALERT_LOG="$work/alert.txt"
  export SDL_VIDEODRIVER=dummy SDL_AUDIODRIVER=dummy
  export LD_PRELOAD="$work/alert-probe.so${LD_PRELOAD:+:$LD_PRELOAD}"
  ./StdFireLimeSpec
)
