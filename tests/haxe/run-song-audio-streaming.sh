#!/usr/bin/env bash
# Exercise the real native streaming helper and the real Paths song-audio
# methods with simulated OpenFL/Lime/asset loaders. No game haxelibs required.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R "$root/tests/haxe/stubs/song-audio/." "$work/"
cp "$root/source/backend/SongAudioStreaming.hx" "$work/backend/SongAudioStreaming.hx"
# Paths records a mod's missing audio for the Mods menu (§19).
cp "$root/source/backend/ModHealth.hx" "$work/backend/ModHealth.hx"

# Keep all cache, routing and fallback tests tied to the actual Paths methods,
# rather than maintaining a second implementation in the stubs.
python3 - "$root/source/backend/Paths.hx" "$work/PathsHarness.hx.txt" "$work/backend/Paths.hx" <<'PY'
from pathlib import Path
import sys
source = Path(sys.argv[1]).read_text()
header = Path(sys.argv[2]).read_text()
voices = '  // Loads the Voices.' + source.split('  // Loads the Voices.', 1)[1].split('  /**\n   * Asset id (`songs:`', 1)[0]
sounds = source.split('  // Asset loading has been rewritten.', 1)[1].split('  #if MODS_ALLOWED\n  // Loads mods.', 1)[0]
Path(sys.argv[3]).write_text(header + voices + sounds + '\n}\n')
PY

cd "$work"
for defs in native fallback; do
  flags=(-D MODS_ALLOWED)
  if [ "$defs" = native ]; then flags+=(-D lime_vorbis -D lime_openal); fi
  "${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" "${flags[@]}" -main SongAudioStreamingSpec --interp
  "${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" "${flags[@]}" -main PathsSongAudioSpec --interp
done
