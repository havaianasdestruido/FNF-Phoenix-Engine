#!/usr/bin/env bash
# Typecheck the stage-dim overlay against the real Flixel sources.
#
# `tests/haxe/run-stage-dim.sh` runs `StageDimMath` and `PlayStateStageDim` against
# small stubs. Stubs accept anything, so they cannot tell whether the Flixel calls
# are right: `scrollFactor.set()`, `cameras = [...]`, `setGraphicSize()` +
# `updateHitbox()`, the `FlxContainer` member API and `FlxColor.BLACK` are all
# checked only by the real library.
#
# This compiles `source/play/helpers/{StageDimMath,PlayStateStageDim}.hx`
# unchanged against flixel/openfl/lime, with a stub `PlayState` that extends the
# real `FlxContainer` and carries the three fields the helper touches.
#
# A second pass checks the real `options.VisualsUISubState`: the helper can be
# perfect while its options row has a typo, and the row is the only way a player
# reaches the feature. (An adjacent-string syntax error there once slipped past
# a typecheck of `PlayState` alone, because nothing reached that class.)
#
# The libraries are found through `haxelib path` (what setup/windows.bat and hmm
# install) or through FLIXEL_PATH / OPENFL_PATH / LIME_PATH. Without them the
# script skips, so it stays usable on a sandbox that only has the Haxe compiler.
# For that reason it is not wired into CI (the Checks job has no game haxelibs,
# so it would only ever print SKIP); `run-stage-dim.sh` is what CI runs.
set -euo pipefail
cd "$(dirname "$0")/../.."

find_lib() {
  local name="$1" envvar="$2" pkg="${3:-$1}" dir=""
  if [ -n "${!envvar:-}" ]; then
    dir="${!envvar}"
  elif command -v haxelib >/dev/null 2>&1; then
    dir=$(haxelib path "$name" 2>/dev/null | head -1 || true)
  fi
  [ -z "$dir" ] && return 1
  if [ -d "$dir/src/$pkg" ]; then
    printf '%s' "$dir/src"
  elif [ -d "$dir/$pkg" ]; then
    printf '%s' "$dir"
  else
    return 1
  fi
}

flixel=$(find_lib flixel FLIXEL_PATH || true)
openfl=$(find_lib openfl OPENFL_PATH || true)
lime=$(find_lib lime LIME_PATH || true)

if [ -z "$flixel" ] || [ -z "$openfl" ] || [ -z "$lime" ]; then
  echo "SKIP: flixel/openfl/lime sources not found (haxelib path or FLIXEL_PATH/OPENFL_PATH/LIME_PATH)"
  exit 0
fi

test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/play/helpers" "$test_source/backend"
cp source/play/helpers/StageDimMath.hx "$test_source/play/helpers/"
cp source/play/helpers/PlayStateStageDim.hx "$test_source/play/helpers/"

# The helper only needs the camera pair, the overlay slot and the member list,
# so `PlayState` is the real `FlxContainer` plus three fields.
cat > "$test_source/play/PlayState.hx" <<'HAXE'
package play;

import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.group.FlxContainer;

class PlayState extends FlxContainer
{
  public var camGame:FlxCamera;
  public var camHUD:FlxCamera;
  public var stageDimOverlay:FlxSprite;

  public function new()
  {
    super();
    camGame = new FlxCamera();
    camHUD = new FlxCamera();
  }
}
HAXE

cat > "$test_source/backend/ClientPrefs.hx" <<'HAXE'
package backend;

class ClientPrefs
{
  public static var stageDim:Float = 0;
}
HAXE

# Exercises the public surface, so a signature change breaks here rather than in
# a song. `LayoutSpec`-style assertions are in run-stage-dim.sh; this only has to
# typecheck.
cat > "$test_source/StageDimTypecheckMain.hx" <<'HAXE'
import backend.ClientPrefs;
import play.PlayState;
import play.helpers.PlayStateStageDim;
import play.helpers.StageDimMath;

class StageDimTypecheckMain
{
  static function main():Void
  {
    final state = new PlayState();
    ClientPrefs.stageDim = 0.35;

    PlayStateStageDim.setup(state);
    PlayStateStageDim.sync(state);
    PlayStateStageDim.syncLayer(state);

    final size = StageDimMath.coverageSize(state.camGame.width, state.camGame.height, state.camGame.zoom, state.camGame.angle);
    final position = StageDimMath.coveragePosition(state.camGame.width, state.camGame.height, size);
    trace(size.width, size.height, position.x, position.y);
    trace(StageDimMath.alpha(ClientPrefs.stageDim), StageDimMath.isVisible(ClientPrefs.stageDim));
    trace(StageDimMath.safeZoom(0), StageDimMath.safeAngle(Math.NaN), StageDimMath.MAX_ALPHA, StageDimMath.STEP);

    PlayStateStageDim.clear(state);
  }
}
HAXE

common="-cp $test_source -cp $flixel -cp $openfl -cp $lime -D lime=8.1.2 -D openfl=9.3.0"

# Reports only diagnostics from the files under test.
#
# Importing `flixel.FlxCamera` drags in `FlxGame`, and a sandbox checkout of
# flixel/openfl/lime can be a few commits off the versions `hmm.json` pins, so
# the library itself may not typecheck cleanly. Those errors are not ours and
# would make the script useless here; anything pointing at the files under test
# still fails the run.
#
# check <main> <files-of-interest-prefix> <flag> <dest> -- <haxe args...>
check() {
  local main="$1" prefix="$2" flag="$3" dest="$4"
  shift 4
  [ "${1:-}" = "--" ] && shift
  local output status=0
  output=$("${HAXE:-haxe}" "$@" -main "$main" "$flag" "$dest" --no-output 2>&1) || status=$?
  local own
  own=$(printf '%s\n' "$output" | grep -F "$prefix" || true)
  if [ -n "$own" ]; then
    printf '%s\n' "$own" >&2
    return 1
  fi
  # A failure with no file position at all (bad arguments, missing class) is ours too.
  if [ "$status" -ne 0 ] && ! printf '%s\n' "$output" | grep -qE ':[0-9]+:'; then
    printf '%s\n' "$output" >&2
    return 1
  fi
  return 0
}

echo "Typechecking the stage-dim overlay for html5..."
# shellcheck disable=SC2086
check StageDimTypecheckMain "$test_source/" -js "$test_source/stage-dim.js" $common -D html5 -D lime_html5 -D lime_webgl -D openfl_html5 -D webgl -D canvas -D dom

echo "Typechecking the stage-dim overlay for native..."
# shellcheck disable=SC2086
check StageDimTypecheckMain "$test_source/" -cpp "$test_source/cpp" $common -D windows -D desktop -D native -D lime_native -D lime_opengl

# --- Pass 2: the real Options row compiles --------------------------------
#
# No stubs: `VisualsUISubState` is the file the change touched, so it is built
# from the real source tree, together with the real ClientPrefs/StageDimMath it
# names. Only the members it does not touch are skipped.
echo "Typechecking the Stage Dim options row..."
# shellcheck disable=SC2086
check options.VisualsUISubState "source/options/VisualsUISubState.hx" \
  -cpp "$test_source/options" -cp source -cp source/source-haxelib-patches \
  -cp "$flixel" -cp "$openfl" -cp "$lime" -D lime=8.1.2 -D openfl=9.3.0 \
  -D windows -D desktop -D native -D lime_native -D lime_opengl

echo "StageDim typecheck: PASS"
