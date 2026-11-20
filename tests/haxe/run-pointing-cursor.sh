#!/usr/bin/env bash
# Pointing-finger menu cursor (HaxeFlixel Cursor demo): pick/anchor math,
# camera-space hover rectangles for scrolling menus (the main menu used to
# snap the selection back up while scrolling down), ClientPrefs defaults,
# VisualsUISubState options, and menu wiring.
set -euo pipefail
cd "$(dirname "$0")/../.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend"
cp source/backend/PointingCursorLogic.hx "$work/backend/"

"${HAXE:-haxe}" -cp "$work" -cp tests/haxe -main PointingCursorSpec --interp

# --- Static wiring guards ----------------------------------------------------
grep -q "public static var pointingCursor:Bool = true;" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.pointingCursor must exist and default to true" >&2; exit 1; }

grep -q "public static var pointingCursorStyle:String = PointingCursorLogic.DEFAULT_STYLE;" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.pointingCursorStyle missing" >&2; exit 1; }

grep -q "public static var pointingCursorColor:String = PointingCursorLogic.DEFAULT_COLOR;" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.pointingCursorColor missing" >&2; exit 1; }

grep -q "PointingCursorLogic.normalizeStyle(pointingCursorStyle)" source/backend/ClientPrefs.hx \
  || { echo "FAIL: loadPrefs must normalize pointingCursorStyle" >&2; exit 1; }

grep -q "PointingCursorLogic.normalizeColor(pointingCursorColor)" source/backend/ClientPrefs.hx \
  || { echo "FAIL: loadPrefs must normalize pointingCursorColor" >&2; exit 1; }

toggle_row=$(grep -A 3 "'pointingCursor'," source/options/VisualsUISubState.hx || true)
[ -n "$toggle_row" ] || { echo "FAIL: no 'pointingCursor' row in VisualsUISubState.hx" >&2; exit 1; }
grep -q "'bool'" <<<"$toggle_row" || { echo "FAIL: pointingCursor option must be bool" >&2; exit 1; }
grep -q "true" <<<"$toggle_row" || { echo "FAIL: pointingCursor option default must be true" >&2; exit 1; }

style_row=$(grep -A 4 "'pointingCursorStyle'," source/options/VisualsUISubState.hx || true)
[ -n "$style_row" ] || { echo "FAIL: no 'pointingCursorStyle' row in VisualsUISubState.hx" >&2; exit 1; }
grep -q "PointingCursorLogic.styleNames()" <<<"$style_row" \
  || { echo "FAIL: pointingCursorStyle must use PointingCursorLogic.styleNames()" >&2; exit 1; }

color_row=$(grep -A 4 "'pointingCursorColor'," source/options/VisualsUISubState.hx || true)
[ -n "$color_row" ] || { echo "FAIL: no 'pointingCursorColor' row in VisualsUISubState.hx" >&2; exit 1; }
grep -q "PointingCursorLogic.colorNames()" <<<"$color_row" \
  || { echo "FAIL: pointingCursorColor must use PointingCursorLogic.colorNames()" >&2; exit 1; }

grep -q "class PointingCursor" source/objects/PointingCursor.hx \
  || { echo "FAIL: objects.PointingCursor must exist" >&2; exit 1; }

# Hover picking must happen in the camera space of the menu members: world
# rectangles against the world pointer drift by
# scroll * (1 - scrollFactor) on scrolling menus (main menu, options), which
# made the finger snap to items the pointer was not on.
grep -q "PointingCursorLogic.screenRect" source/objects/PointingCursor.hx \
  || { echo "FAIL: hover picking must build camera-space rects (PointingCursorLogic.screenRect)" >&2; exit 1; }

grep -q "FlxG.mouse.getScreenPosition" source/objects/PointingCursor.hx \
  || { echo "FAIL: the pointer must be read in the members' camera space (FlxG.mouse.getScreenPosition)" >&2; exit 1; }

# The movement gate must compare the raw pointer position: FlxG.mouse.x/y are
# world coordinates that move while a menu camera pans or zooms, which
# re-triggered hover picking without the player touching the mouse.
grep -q "FlxG.game.mouseX" source/objects/PointingCursor.hx \
  || { echo "FAIL: the movement gate must compare the raw pointer (FlxG.game.mouseX)" >&2; exit 1; }

grep -q "function syncPointingCursor" source/backend/MusicBeatState.hx \
  || { echo "FAIL: MusicBeatState must expose syncPointingCursor" >&2; exit 1; }

grep -q "function syncPointingCursor" source/backend/MusicBeatSubstate.hx \
  || { echo "FAIL: MusicBeatSubstate must expose syncPointingCursor" >&2; exit 1; }

grep -q "syncPointingCursor(menuItems.members, curSelected)" source/states/MainMenuState.hx \
  || { echo "FAIL: MainMenuState must point the cursor at menu items" >&2; exit 1; }

grep -q "syncPointingCursor(grpOptions.members, curSelected)" source/options/BaseOptionsMenu.hx \
  || { echo "FAIL: BaseOptionsMenu must point the cursor at option rows" >&2; exit 1; }

grep -q "syncPointingCursor(menuItemGroup.members, curSelected)" source/states/substates/PauseSubState.hx \
  || { echo "FAIL: PauseSubState must point the cursor at pause rows" >&2; exit 1; }

grep -q "syncPointingCursor(grpWeekText.members, curWeek)" source/states/StoryMenuState.hx \
  || { echo "FAIL: StoryMenuState must point the cursor at week items" >&2; exit 1; }

grep -q "syncPointingCursor(grpSongs.members, curSelected)" source/states/FreeplayState.hx \
  || { echo "FAIL: FreeplayState must point the cursor at songs" >&2; exit 1; }

grep -q "syncPointingCursor(grpOptions.members, curSelected)" source/options/OptionsState.hx \
  || { echo "FAIL: OptionsState must point the cursor at categories" >&2; exit 1; }

echo "Pointing cursor wiring checks: PASS"
