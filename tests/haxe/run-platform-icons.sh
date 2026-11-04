#!/usr/bin/env bash
# Platform badge contract: target detection, density math and glyph bounds.
# backend/PlatformIcons.hx is deliberately free of Flixel/OpenFL/Lime imports
# so this runs with nothing but the Haxe compiler.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/PlatformIcons.hx "$test_source/backend/PlatformIcons.hx"

# No define: the runtime system name decides.
echo 'Platform icon interpreter target: runtime system name'
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main PlatformIconSpec --interp

for platform in windows mac linux android ios html5 air; do
  echo "Platform icon interpreter target: $platform"
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D "$platform" -main PlatformIconSpec --interp
done

# `flash` is a reserved compiler flag, not a user define. Compile for the real
# SWF target instead, and check the selected detect() branch at compile time.
# AIR defines `flash` too, and must take priority over it. No Flash player is
# needed; the interpreter runs above cover the density/raster/artwork behavior.
for platform in flash air; do
  defines=()
  if [[ "$platform" == air ]]; then defines=(-D air); fi
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe "${defines[@]}" \
    --macro "PlatformIconTargetCheck.expect('$platform')" \
    -main PlatformIconSpec -swf "$test_source/$platform.swf"
done
