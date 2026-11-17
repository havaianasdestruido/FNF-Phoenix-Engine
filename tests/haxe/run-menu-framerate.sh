#!/usr/bin/env bash
# Menu framerate (ClientPrefs.menuFramerate) and the focus-lost rate
# (ClientPrefs.focusLostFramerate): menus run at their own cap instead of
# inheriting the gameplay rate, which can be set up to 1000/10000.
#
# `backend.FramerateMath` is Flixel-free; the FlxG writes live in
# `backend.FramerateController` and are pinned here with static checks.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/FramerateMath.hx "$test_source/backend/"

"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main FramerateSpec --interp

# --- Static guard: the preferences exist with the documented defaults ---------
grep -q "public static var menuFramerate:Int = 60;" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.menuFramerate is missing or its default is not 60" >&2; exit 1; }
grep -q "public static var focusLostFramerate:Int = 60;" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.focusLostFramerate is missing or its default is not 60" >&2; exit 1; }

# --- Static guard: rows exist in Options -> Graphics -------------------------
for row in "'menuFramerate'," "'focusLostFramerate'," "Menu Framerate" "Focus Lost Framerate"; do
  grep -qF "$row" source/options/GraphicsSettingsSubState.hx \
    || { echo "FAIL: GraphicsSettingsSubState.hx is missing '$row'" >&2; exit 1; }
done
grep -q "onChangeMenuFramerate" source/options/GraphicsSettingsSubState.hx \
  || { echo "FAIL: the Menu Framerate row does not apply immediately" >&2; exit 1; }
grep -q "applyFocusLost" source/options/GraphicsSettingsSubState.hx \
  || { echo "FAIL: the Focus Lost Framerate row does not apply immediately" >&2; exit 1; }

# --- Static guard: states run at the rate they are created with --------------
grep -q "FramerateController.applyForState(this)" source/backend/MusicBeatState.hx \
  || { echo "FAIL: MusicBeatState.create() does not apply the per-state rate" >&2; exit 1; }
grep -q "applyFocusLost" source/states/InitState.hx \
  || { echo "FAIL: InitState does not apply the saved focus-lost rate" >&2; exit 1; }
grep -q "apply(ClientPrefs.menuFramerate)" source/states/InitState.hx \
  || { echo "FAIL: InitState does not apply the menu rate" >&2; exit 1; }
grep -q "menuFramerate" source/states/RecoveryState.hx \
  || { echo "FAIL: RecoveryState does not run at the menu rate" >&2; exit 1; }
grep -q "applyForState" source/backend/SettingsBackup.hx \
  || { echo "FAIL: SettingsBackup.applyImmediately does not re-apply the current rate" >&2; exit 1; }

# The hard-coded 60 this preference replaces must be gone from InitState.
grep -q "FlxG.game.focusLostFramerate = 60" source/states/InitState.hx \
  && { echo "FAIL: InitState still hard-codes the focus-lost framerate" >&2; exit 1; }

echo "Menu framerate checks: PASS"
