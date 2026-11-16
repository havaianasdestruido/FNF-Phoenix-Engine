#!/usr/bin/env bash
# Bottom-left FlxPieDial loading indicator: pure math, Flixel widget stubs,
# ClientPrefs defaults, VisualsUISubState options, and LoadingState/CopyState wiring.
set -euo pipefail
cd "$(dirname "$0")/../.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R tests/haxe/stubs/loading-dial/. "$work/"
mkdir -p "$work/backend" "$work/objects"
cp source/backend/LoadingDialLogic.hx "$work/backend/"
cp source/objects/LoadingPieDial.hx "$work/objects/"

"${HAXE:-haxe}" -cp "$work" -cp tests/haxe -main LoadingDialSpec --interp
"${HAXE:-haxe}" -cp "$work" -cp tests/haxe -main LoadingDialSpec -js "$work/dial.js"
node "$work/dial.js"

# --- Static wiring guards ----------------------------------------------------
grep -q "public static var loadingPieDial:Bool = true;" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.loadingPieDial must exist and default to true" >&2; exit 1; }

grep -q "public static var loadingPieDialColor:String = LoadingDialLogic.DEFAULT_COLOR;" source/backend/ClientPrefs.hx \
  || { echo "FAIL: ClientPrefs.loadingPieDialColor missing" >&2; exit 1; }

grep -q "LoadingDialLogic.normalizeColor(loadingPieDialColor)" source/backend/ClientPrefs.hx \
  || { echo "FAIL: loadPrefs must normalize loadingPieDialColor" >&2; exit 1; }

toggle_row=$(grep -A 3 "'loadingPieDial'," source/options/VisualsUISubState.hx || true)
[ -n "$toggle_row" ] || { echo "FAIL: no 'loadingPieDial' row in VisualsUISubState.hx" >&2; exit 1; }
grep -q "'bool'" <<<"$toggle_row" || { echo "FAIL: loadingPieDial option must be bool" >&2; exit 1; }
grep -q "true" <<<"$toggle_row" || { echo "FAIL: loadingPieDial option default must be true" >&2; exit 1; }

color_row=$(grep -A 4 "'loadingPieDialColor'," source/options/VisualsUISubState.hx || true)
[ -n "$color_row" ] || { echo "FAIL: no 'loadingPieDialColor' row in VisualsUISubState.hx" >&2; exit 1; }
grep -q "'string'" <<<"$color_row" || { echo "FAIL: loadingPieDialColor option must be string" >&2; exit 1; }
grep -q "LoadingDialLogic.colorNames()" <<<"$color_row" || { echo "FAIL: loadingPieDialColor must use LoadingDialLogic.colorNames()" >&2; exit 1; }

grep -q "pieDial = new LoadingPieDial();" source/states/LoadingState.hx \
  || { echo "FAIL: LoadingState must create LoadingPieDial" >&2; exit 1; }
grep -q "pieDial.setProgress(newSize);" source/states/LoadingState.hx \
  || { echo "FAIL: LoadingState.changeBarSize must drive pieDial.setProgress" >&2; exit 1; }
grep -q "pieDial.layout(width, height);" source/states/LoadingState.hx \
  || { echo "FAIL: LoadingState.onResize must re-layout pieDial" >&2; exit 1; }

grep -q "pieDial = new LoadingPieDial(dialColor);" source/mobile/CopyState.hx \
  || { echo "FAIL: CopyState must create LoadingPieDial" >&2; exit 1; }
grep -q "pieDial.setProgress(ratio);" source/mobile/CopyState.hx \
  || { echo "FAIL: CopyState.update must drive pieDial.setProgress" >&2; exit 1; }
grep -q "pieDial.layout(width, height);" source/mobile/CopyState.hx \
  || { echo "FAIL: CopyState.onResize must re-layout pieDial" >&2; exit 1; }

echo "Loading dial wiring checks: PASS"
