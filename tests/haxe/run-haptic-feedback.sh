#!/usr/bin/env bash
# Automatic note haptics, duration sanitization and Lua/Python vibrate() parity.
# Uses a recording Android bridge stub; no JNI, Flixel or game haxelibs needed.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/play/helpers" "$test_source/psychlua/callbacks" "$test_source/psychlua/pystdlib"
cp source/backend/HapticFeedback.hx "$test_source/backend/"
cp source/backend/PlatformIcons.hx source/backend/PlatformSupport.hx "$test_source/backend/"
cp source/play/helpers/PlayStateHaptics.hx "$test_source/play/helpers/"
cp source/psychlua/callbacks/HardwareCallbacks.hx "$test_source/psychlua/callbacks/"
cp source/psychlua/pystdlib/PyHardwareLib.hx "$test_source/psychlua/pystdlib/"
cp -r tests/haxe/stubs/haptics/. "$test_source/"

spec() {
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main HapticFeedbackSpec "$@"
}

# Unsupported target: policy still runs, bridge stays silent.
spec --interp
# Android target: the stub records the exact pulses and cancels.
spec -D android --interp
