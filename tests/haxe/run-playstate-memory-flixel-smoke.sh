#!/usr/bin/env bash
# Optional real-PlayState integration smoke on Linux/Neko, with dummy video
# and OpenAL's null audio driver. It needs the project's pinned libraries:
# LIME_PATH=... OPENFL_PATH=... FLIXEL_PATH=... FLIXEL_ADDONS_PATH=... \
# FLIXEL_UI_PATH=... TJSON_PATH=... NEKO=... bash tests/haxe/run-playstate-memory-flixel-smoke.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "$(uname -s)" != Linux ]; then
  echo 'SKIP: the PlayState memory smoke currently requires Linux/Neko'
  exit 0
fi
for name in LIME_PATH OPENFL_PATH FLIXEL_PATH FLIXEL_ADDONS_PATH FLIXEL_UI_PATH TJSON_PATH; do
  if [ -z "${!name:-}" ]; then
    echo 'SKIP: set LIME_PATH, OPENFL_PATH, FLIXEL_PATH, FLIXEL_ADDONS_PATH, FLIXEL_UI_PATH and TJSON_PATH'
    exit 0
  fi
  if [ ! -d "${!name}" ]; then
    echo "ERROR: $name is not a directory: ${!name}" >&2
    exit 1
  fi
  printf -v "$name" '%s' "$(cd "${!name}" && pwd)"
  export "$name"
done
neko_bin="$(command -v "${NEKO:-neko}" || true)"
if [ -z "$neko_bin" ]; then
  echo 'SKIP: Neko executable not found (set NEKO)'
  exit 0
fi
neko_bin="$(cd "$(dirname "$neko_bin")" && pwd)/$(basename "$neko_bin")"
if [ ! -f "$LIME_PATH/ndll/Linux64/lime.ndll" ] || [ ! -d "$LIME_PATH/src/lime" ] \
  || [ ! -d "$OPENFL_PATH/src/openfl" ] || [ ! -f "$FLIXEL_PATH/flixel/ui/FlxBar.hx" ] \
  || [ ! -d "$FLIXEL_ADDONS_PATH/flixel/addons" ] || [ ! -d "$FLIXEL_UI_PATH/flixel/addons/ui" ] \
  || [ ! -d "$FLIXEL_UI_PATH/assets/images" ] || [ ! -d "$TJSON_PATH/tjson" ]; then
  echo 'ERROR: library roots must contain their sources and Lime Linux64 native ndll' >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/flixel/ui" "$work/run/assets" "$work/run/mods" "$work/home"
cp "$root/tests/haxe/PlayStateMemoryFlixelSmoke.hx" "$work/"
# FlxBar accesses uninitialized Float fields while constructing a software
# bar. Native C++ initializes them to zero; Neko leaves them null. Give only
# this temporary test copy equivalent defaults, leaving the library unchanged.
python3 - "$FLIXEL_PATH/flixel/ui/FlxBar.hx" "$work/flixel/ui/FlxBar.hx" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
for field, value in [('value(get, set)', '0'), ('min(default, null)', '0'),
                     ('max(default, null)', '100'), ('range(default, null)', '100'),
                     ('pct(default, null)', '1')]:
    old = 'public var ' + field + ':Float;'
    if source.count(old) != 1:
        raise SystemExit('Unexpected FlxBar source; cannot apply Neko test shim: ' + field)
    source = source.replace(old, 'public var ' + field + ':Float = ' + value + ';')
Path(sys.argv[2]).write_text(source)
PY
for dir in characters data gameRenders images music sounds stages weeks; do
  ln -s "$root/assets/preload/$dir" "$work/run/assets/$dir"
done
for dir in shared songs fonts week2 week3 week4 week5 week6 week7 weekend1; do
  ln -s "$root/assets/$dir" "$work/run/assets/$dir"
done

common=(-cp "$LIME_PATH/src" -cp "$OPENFL_PATH/src" -cp "$FLIXEL_PATH" -cp "$FLIXEL_ADDONS_PATH"
  -cp "$FLIXEL_UI_PATH" -cp "$TJSON_PATH" -cp "$root/source" -cp "$root/source/source-haxelib-patches" -cp "$work"
  -D flixel=5.6.1 -D flixel_addons=3.2.3 -D lime=8.1.2 -D openfl=9.3.3 -D tools -D native
  -D lime_native -D lime_cffi -D lime_opengl -D lime_openal -D lime_vorbis -D FLX_PITCH -D FLX_SOUND_SYSTEM
  -D FLX_SOUND_TRAY -D FLX_KEYBOARD -D FLX_MOUSE -D FLX_MOUSE_ADVANCED -D FLX_TOUCH -D FLX_GAMEPAD
  -D FLX_GAMEINPUT_API -D FLX_SAVE)
for mode in no-mods mods; do
  flags=()
  if [ "$mode" = mods ]; then flags+=(-D MODS_ALLOWED); fi
  "${HAXE:-haxe}" "${common[@]}" -D desktop "${flags[@]}" -main PlayStateMemoryFlixelSmoke -cpp "$work/cpp" --no-output
done
# This checks Android conditional code only; it does not build/link an APK.
"${HAXE:-haxe}" "${common[@]}" -D android -D mobile -D MODS_ALLOWED -main PlayStateMemoryFlixelSmoke -cpp "$work/android-cpp" --no-output
"${HAXE:-haxe}" "${common[@]}" -D desktop -main PlayStateMemoryFlixelSmoke -neko "$work/smoke-no-mods.n"
"${HAXE:-haxe}" "${common[@]}" -D desktop -D MODS_ALLOWED -main PlayStateMemoryFlixelSmoke -neko "$work/smoke.n"

neko_dir="$(dirname "$neko_bin")"
cd "$work/run"
export HOME="$work/home" SDL_VIDEODRIVER="${SDL_VIDEODRIVER:-dummy}" ALSOFT_DRIVERS="${ALSOFT_DRIVERS:-null}"
export NEKOPATH="$LIME_PATH/ndll/Linux64:$neko_dir${NEKOPATH:+:$NEKOPATH}"
export LD_LIBRARY_PATH="$neko_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
"$neko_bin" "$work/smoke-no-mods.n"
"$neko_bin" "$work/smoke-no-mods.n" pixel
"$neko_bin" "$work/smoke.n"
"$neko_bin" "$work/smoke.n" replacement
"$neko_bin" "$work/smoke.n" pixel
"$neko_bin" "$work/smoke.n" profile-off
"$neko_bin" "$work/smoke.n" restart
"$neko_bin" "$work/smoke.n" pixel profile-off restart
"$neko_bin" "$work/smoke.n" pixel complete-pixel-skin
