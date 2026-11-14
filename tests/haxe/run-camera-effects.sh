#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
cp -R "$root/tests/haxe/stubs/camera-effects/." "$work/"
cp "$root/source/backend/CameraEffects.hx" "$work/backend/"
# Isolate the real shake override from unrelated rendering/follow dependencies.
# The body and signature are copied verbatim, not reimplemented by a test double.
{ printf 'package backend;\nimport flixel.FlxCamera;\nclass PsychCamera extends FlxCamera\n{\n';
  sed -n '/override public function shake(/,/override public function update(/p' \
    "$root/source/backend/PsychCamera.hx" | sed '$d';
  printf '}\n';
} > "$work/backend/PsychCamera.hx"
"${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -main CameraEffectsSpec --interp
