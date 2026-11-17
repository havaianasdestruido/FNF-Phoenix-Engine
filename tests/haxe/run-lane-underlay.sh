#!/usr/bin/env bash
# Lane underlay (ClientPrefs.laneUnderlayAlpha): the dark strip behind the
# player's lanes. Alpha/span rules, the strip's lifecycle and its layering
# under the strums on the notes camera.
#
# `play.helpers.LaneUnderlayMath` is Flixel-free and `PlayStateLaneUnderlay`
# only needs a small camera/sprite surface, so both run under the Haxe
# interpreter with the stubs in tests/haxe/stubs/lane-underlay, without the
# game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -R tests/haxe/stubs/lane-underlay/. "$test_source/"
mkdir -p "$test_source/play/helpers"
cp source/play/helpers/LaneUnderlayMath.hx "$test_source/play/helpers/"
cp source/play/helpers/PlayStateLaneUnderlay.hx "$test_source/play/helpers/"

"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main LaneUnderlaySpec --interp

# --- Static guard: the Options row is actually wired to the preference -------
row=$(grep -A 3 "'laneUnderlayAlpha'," source/options/VisualsUISubState.hx || true)
[ -n "$row" ] || { echo "FAIL: no 'laneUnderlayAlpha' row in VisualsUISubState.hx" >&2; exit 1; }

grep -q "'percent'" <<<"$row" || { echo "FAIL: the laneUnderlayAlpha row must be a percent option" >&2; exit 1; }

grep -q "public static var laneUnderlayAlpha:Float" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.laneUnderlayAlpha is missing or not a Float" >&2; exit 1; }

row_block=$(awk "/new Option\('Lane Underlay:'/,/addOption\(option\);/" source/options/VisualsUISubState.hx)
[ -n "$row_block" ] || { echo "FAIL: could not isolate the Lane Underlay options row" >&2; exit 1; }

for want in \
  "option.changeValue = LaneUnderlayMath.STEP;" \
  "option.maxValue = LaneUnderlayMath.MAX_ALPHA;" \
  "option.minValue = LaneUnderlayMath.MIN_ALPHA;" \
  "option.decimals = 2;" \
  "addOption(option);"
do
  grep -qF "$want" <<<"$row_block" || { echo "FAIL: the Lane Underlay row is missing '$want'" >&2; exit 1; }
done

# --- Static guard: the play state owns the strip's lifecycle -----------------
grep -q "PlayStateLaneUnderlay.setup(this)" source/play/PlayState.hx \
  || { echo "FAIL: PlayState.create() does not set up the lane underlay" >&2; exit 1; }
grep -q "PlayStateLaneUnderlay.sync(this)" source/play/PlayState.hx \
  || { echo "FAIL: PlayState.update() does not sync the lane underlay" >&2; exit 1; }
grep -q "PlayStateLaneUnderlay.clear(this)" source/play/PlayState.hx \
  || { echo "FAIL: PlayState.destroy() does not tear down the lane underlay" >&2; exit 1; }

echo "Lane underlay checks: PASS"
