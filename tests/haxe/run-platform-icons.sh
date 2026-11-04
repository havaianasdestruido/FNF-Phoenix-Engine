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
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main PlatformIconSpec --interp

for platform in windows mac linux android ios html5 flash; do
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D "$platform" -main PlatformIconSpec --interp
done

# AIR builds define `flash` as well; the badge must still say AIR.
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -D air -D flash -main PlatformIconSpec --interp
