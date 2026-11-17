#!/usr/bin/env bash
# The Freeplay filter (sort by name/mod/accuracy/unplayed, show one mod, stars,
# random song), compiled and run in the Haxe interpreter without any game
# haxelibs:
#
#   backend/FreeplayFilter.hx   the renderer-free half: the search box, the mod
#                               filter, the four orders, the star keys, the
#                               random pick and the Highscore -> best accuracy
#                               fold. No stubs: the module imports nothing but
#                               the standard library.
#
# The page that draws it (`states/substates/FreeplayFilterSubState.hx`) and the
# Freeplay wiring are Flixel code; this spec covers the part that decides which
# songs the player sees and in what order.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/logic/backend"

cp source/backend/FreeplayFilter.hx "$test_source/logic/backend/"
"${HAXE:-haxe}" -cp "$test_source/logic" -cp tests/haxe -main FreeplayFilterSpec --interp

# The game is built as C++, a static target, where a Float cannot hold null and
# an Int cannot be compared with it. The interpreter above is a dynamic target
# and accepts both, so the same sources are also typechecked for C++ (nothing is
# generated).
"${HAXE:-haxe}" -cp "$test_source/logic" -cp tests/haxe -main FreeplayFilterSpec -cpp "$test_source/cpp" --no-output
