#!/usr/bin/env bash
# Optional real Flixel/OpenFL/Lime character smoke on Linux/Neko.
# LIME_PATH=... OPENFL_PATH=... FLIXEL_PATH=... FLIXEL_ADDONS_PATH=... NEKO=... bash tests/haxe/run-song-character-flixel-smoke.sh
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
if [ "$(uname -s)" != Linux ]; then
  echo 'SKIP: character smoke currently requires Linux/Neko'
  exit 0
fi
if [ -z "${LIME_PATH:-}" ] || [ -z "${OPENFL_PATH:-}" ] || [ -z "${FLIXEL_PATH:-}" ] || [ -z "${FLIXEL_ADDONS_PATH:-}" ]; then
  echo 'SKIP: set LIME_PATH, OPENFL_PATH, FLIXEL_PATH and FLIXEL_ADDONS_PATH to the pinned library roots'
  exit 0
fi
neko_bin="$(command -v "${NEKO:-neko}" || true)"
if [ -z "$neko_bin" ]; then
  echo 'SKIP: Neko executable not found (set NEKO)'
  exit 0
fi
if [ ! -f "$LIME_PATH/ndll/Linux64/lime.ndll" ] || [ ! -d "$LIME_PATH/src/lime" ] \
  || [ ! -d "$OPENFL_PATH/src/openfl" ] || [ ! -d "$FLIXEL_PATH/flixel" ] \
  || [ ! -d "$FLIXEL_ADDONS_PATH/flixel/addons" ]; then
  echo 'ERROR: library roots must contain their sources and Lime Linux64 native ndll' >&2
  exit 1
fi
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R "$root/tests/haxe/stubs/song-character-flixel/." "$work/"
mkdir -p "$work/objects" "$work/play/helpers"
cp "$root/source/objects/Character.hx" "$work/objects/"
cp "$root/source/play/helpers/"{SongCharacterInfo,PlayStateCharacters,PlayStateCharacterEvents,CharacterNoteSkin}.hx "$work/play/helpers/"
cp "$root/source/import.hx" "$work/"
cp -R "$root/source/utils" "$work/"
cp "$root/tests/haxe/"{SongCharacterFlixelSmoke,SongCharacterChangeFlixelSmoke}.hx "$work/"
common=(-cp "$LIME_PATH/src" -cp "$OPENFL_PATH/src" -cp "$FLIXEL_PATH" -cp "$FLIXEL_ADDONS_PATH" -cp "$work"
  -D lime=8.1.2 -D openfl=9.3.3 -D desktop -D native -D lime_native -D lime_cffi -D lime_opengl -D FLX_PITCH -D FLX_SOUND_SYSTEM)
neko_dir="$(dirname "$neko_bin")"
for spec in SongCharacterFlixelSmoke SongCharacterChangeFlixelSmoke; do
  # Check the real code in both asset-resolution configurations.
  for mode in no-mods mods; do
    flags=()
    if [ "$mode" = mods ]; then flags+=(-D MODS_ALLOWED); fi
    "${HAXE:-haxe}" "${common[@]}" "${flags[@]}" -main "$spec" -cpp "$work/cpp" --no-output
  done
  "${HAXE:-haxe}" "${common[@]}" -D MODS_ALLOWED -main "$spec" -neko "$work/smoke.n"
  NEKOPATH="$LIME_PATH/ndll/Linux64:$neko_dir${NEKOPATH:+:$NEKOPATH}" \
  LD_LIBRARY_PATH="$neko_dir${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}" \
    "$neko_bin" "$work/smoke.n"
done
