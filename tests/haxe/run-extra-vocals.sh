#!/usr/bin/env bash
# Exercise the chart extra-vocals parser and runtime in isolation (no game
# haxelibs needed). FLX_PITCH is defined so the pitch branch of the production
# helper is compiled too.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/data" "$work/play/helpers"
cp "$root/source/data/ExtraVocals.hx" "$work/data/"
cp "$root/source/play/helpers/PlayStateExtraVocals.hx" "$work/play/helpers/"
cp -r "$root/tests/haxe/stubs/extra-vocals/." "$work/"
for spec in ExtraVocalsSpec PlayStateExtraVocalsSpec; do
  "${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -D FLX_PITCH -main "$spec" --interp
  "${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -D FLX_PITCH -main "$spec" -js "$work/extra-vocals.js"
  node "$work/extra-vocals.js"
done
