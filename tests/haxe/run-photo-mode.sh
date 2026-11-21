#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend"
cp "$root/source/backend/PhotoModeMath.hx" "$work/backend/"
"${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -main PhotoModeSpec --interp

grep -q "'Photo Mode'" "$root/source/states/substates/PauseSubState.hx" \
  || { echo "FAIL: the pause menu does not list Photo Mode" >&2; exit 1; }
grep -q "new PhotoModeSubState()" "$root/source/states/substates/PauseSubState.hx" \
  || { echo "FAIL: Photo Mode is not opened from the pause menu" >&2; exit 1; }
grep -q "camGame.target = null" "$root/source/states/substates/PhotoModeSubState.hx" \
  || { echo "FAIL: Photo Mode does not detach the gameplay camera follow" >&2; exit 1; }
grep -q "camera.visible = false" "$root/source/states/substates/PhotoModeSubState.hx" \
  || { echo "FAIL: Photo Mode does not hide the non-gameplay cameras" >&2; exit 1; }
grep -q "new Screenshot().save('screenshots')" "$root/source/states/substates/PhotoModeSubState.hx" \
  || { echo "FAIL: Photo Mode does not use the existing screenshot writer" >&2; exit 1; }
grep -q "SSPlugin.clearPreview()" "$root/source/states/substates/PhotoModeSubState.hx" \
  || { echo "FAIL: Photo Mode does not clear the previous screenshot overlay" >&2; exit 1; }

echo "Photo Mode wiring checks: PASS"
