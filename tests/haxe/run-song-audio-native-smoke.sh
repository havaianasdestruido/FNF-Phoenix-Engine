#!/usr/bin/env bash
# Optional real-library smoke on Linux; no game build or display required.
# Supply the project's pinned Lime, OpenFL and Flixel directories, plus Neko:
#   LIME_PATH=... OPENFL_PATH=... FLIXEL_PATH=... NEKO=... bash tests/haxe/run-song-audio-native-smoke.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "$(uname -s)" != Linux ] || [ ! -d /proc/self/fd ]; then
  echo 'SKIP: native song-audio smoke currently requires Linux /proc'
  exit 0
fi
if [ -z "${LIME_PATH:-}" ] || [ -z "${OPENFL_PATH:-}" ] || [ -z "${FLIXEL_PATH:-}" ]; then
  echo 'SKIP: set LIME_PATH, OPENFL_PATH and FLIXEL_PATH to the pinned library roots'
  exit 0
fi
neko_bin="$(command -v "${NEKO:-neko}" || true)"
if [ -z "$neko_bin" ]; then
  echo 'SKIP: Neko executable not found (set NEKO)'
  exit 0
fi
if [ ! -f "$LIME_PATH/ndll/Linux64/lime.ndll" ] || [ ! -d "$LIME_PATH/src/lime" ] \
  || [ ! -d "$OPENFL_PATH/src/openfl" ] || [ ! -d "$FLIXEL_PATH/flixel" ]; then
  echo 'ERROR: library roots must contain their sources and Lime Linux64 native ndll' >&2
  exit 1
fi

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend" "$work/flixel/sound"
cp "$root/source/backend/SongAudioStreaming.hx" "$work/backend/"
cp "$root/source/source-haxelib-patches/flixel/sound/FlxSound.hx" "$work/flixel/sound/"
cp "$root/tests/haxe/SongAudioNativeSmoke.hx" "$work/"
"${HAXE:-haxe}" -cp "$LIME_PATH/src" -cp "$OPENFL_PATH/src" -cp "$FLIXEL_PATH" -cp "$work" \
  -D lime=8.1.2 -D openfl=9.3.3 -D lime_vorbis -D lime_openal -D lime_native \
  -D lime_cffi -D desktop -D FLX_PITCH -main SongAudioNativeSmoke -neko "$work/smoke.n"

# The null driver still runs real OpenAL sources, but doesn't open speakers.
# NEKOPATH locates Lime's native CFFI module; some standalone Neko bundles also
# need their own directory on LD_LIBRARY_PATH to load libneko.
neko_dir="$(dirname "$neko_bin")"
ALSOFT_DRIVERS="${ALSOFT_DRIVERS:-null}" \
NEKOPATH="$LIME_PATH/ndll/Linux64:$neko_dir${NEKOPATH:+:$NEKOPATH}" \
LD_LIBRARY_PATH="$neko_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
  "$neko_bin" "$work/smoke.n" "$root/assets/songs/bopeebo/Inst.ogg"
