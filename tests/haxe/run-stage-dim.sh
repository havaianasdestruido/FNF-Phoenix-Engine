#!/usr/bin/env bash
# Stage dim (ClientPrefs.stageDim): alpha rules, percent safety, the overlay's
# lifecycle and its layering against the note/HUD cameras.
#
# `play.helpers.StageDimMath` is Flixel-free and `PlayStateStageDim` only needs a
# small camera/sprite surface, so both run under the Haxe interpreter with the
# stubs in tests/haxe/stubs/stage-dim, without the game haxelibs.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
cp -R tests/haxe/stubs/stage-dim/. "$test_source/"
mkdir -p "$test_source/play/helpers"
cp source/play/helpers/StageDimMath.hx "$test_source/play/helpers/"
cp source/play/helpers/PlayStateStageDim.hx "$test_source/play/helpers/"

"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main StageDimSpec --interp

# --- Static guard: the Options row is actually wired to the preference -------
# The overlay can be perfect and still never dim anything if the row points at
# another `ClientPrefs` field, or if its step is finer than the precision the
# menu rounds to (`BaseOptionsMenu` rounds the held value with
# `option.decimals`, so `decimals = 0` would round every 0.05 step back to 0 and
# the row could never leave 0%).
row=$(grep -A 3 "'stageDim'," source/options/VisualsUISubState.hx || true)
[ -n "$row" ] || { echo "FAIL: no 'stageDim' row in VisualsUISubState.hx" >&2; exit 1; }

grep -q "'percent'" <<<"$row" || { echo "FAIL: the stageDim row must be a percent option" >&2; exit 1; }

grep -q "public static var stageDim:Float" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.stageDim is missing or not a Float" >&2; exit 1; }

# Slice the row out of the file: from its `new Option('Stage Dim:',` line to
# the `addOption(option);` that closes it, so no other row's settings leak in.
row_block=$(awk "/new Option\('Stage Dim:'/,/addOption\(option\);/" source/options/VisualsUISubState.hx)
[ -n "$row_block" ] || { echo "FAIL: could not isolate the Stage Dim options row" >&2; exit 1; }

for want in \
  "option.changeValue = StageDimMath.STEP;" \
  "option.maxValue = StageDimMath.MAX_ALPHA;" \
  "option.minValue = StageDimMath.MIN_ALPHA;" \
  "option.decimals = 2;" \
  "addOption(option);"
do
  grep -qF "$want" <<<"$row_block" || { echo "FAIL: the Stage Dim row is missing '$want'" >&2; exit 1; }
done

echo "Stage dim options-row check: PASS"
