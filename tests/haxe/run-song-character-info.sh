#!/usr/bin/env bash
# Exercise the metadata-only song character path without renderer dependencies.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R "$root/tests/haxe/stubs/song-character-info/." "$work/"
mkdir -p "$work/play/helpers"
cp "$root/source/play/helpers/SongCharacterInfo.hx" "$work/play/helpers/"
cp "$root/source/play/helpers/SongStagePolicy.hx" "$work/play/helpers/"
for spec in SongCharacterInfoSpec SongStagePolicySpec; do
  "${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -main "$spec" --interp
  "${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -main "$spec" -js "$work/info.js"
  node "$work/info.js"
done
