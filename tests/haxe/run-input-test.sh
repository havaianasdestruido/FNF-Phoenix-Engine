#!/usr/bin/env bash
# The input tester (`phoenix://input`, Options -> Gameplay -> Input Tester),
# compiled and run in the Haxe interpreter without any game haxelibs:
#
#   backend/InputTestLogic.hx   counts what is held per device, measures how far
#                               apart presses arrive and what a once-per-frame
#                               poll would miss, and runs the hold-to-leave
#                               gesture. No stubs: the module imports nothing.
#   states/InputTestState.hx    the page that feeds it from stage key events,
#                               FlxG.gamepads, FlxG.touches and the mouse, and
#                               draws it. Runs against tests/haxe/stubs/input-test
#                               with the production InputFormatter, HardwareKeys,
#                               ScreenLayout, HoldToConfirmLogic, TouchlessUI and
#                               AndroidTVPolicy.
#
# tests/haxe/run-input-test-typecheck.sh checks the same page against the real
# Flixel/OpenFL/Lime sources when they are installed.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/logic/backend" "$test_source/page/backend" "$test_source/page/states"

cp source/backend/InputTestLogic.hx "$test_source/logic/backend/"
"${HAXE:-haxe}" -cp "$test_source/logic" -cp tests/haxe -main InputTestLogicSpec --interp

# The game is built as C++, a static target, where a Float cannot hold null and
# an Int cannot be compared with it. The interpreter above is a dynamic target
# and accepts both, so the same sources are also typechecked for C++ (nothing is
# generated).
"${HAXE:-haxe}" -cp "$test_source/logic" -cp tests/haxe -main InputTestLogicSpec -cpp "$test_source/cpp" --no-output

cp -r tests/haxe/stubs/input-test/. "$test_source/page/"
cp source/states/InputTestState.hx "$test_source/page/states/"
for module in InputTestLogic InputFormatter HardwareKeys HoldToConfirmLogic ScreenLayout TouchlessUI AndroidTVPolicy; do
  cp "source/backend/$module.hx" "$test_source/page/backend/"
done
# Flixel defines FLX_TOUCH and FLX_MOUSE unless a project opts out (Phoenix does
# not), and the page compiles its touch and mouse reads behind them.
"${HAXE:-haxe}" -cp "$test_source/page" -cp tests/haxe -D FLX_TOUCH -D FLX_MOUSE -main InputTestStateSpec --interp
"${HAXE:-haxe}" -cp "$test_source/page" -cp tests/haxe -D FLX_TOUCH -D FLX_MOUSE -main InputTestStateSpec -cpp "$test_source/cpp" --no-output
