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

spec() {
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main PlatformIconSpec "$@"
}

# No define: the runtime system name decides.
spec --interp

for platform in windows mac linux android ios html5 air; do
  spec -D "$platform" --interp
done

# `flash` is a reserved compiler flag, so the Flash branch cannot be faked with
# -D: compile for the real target instead. --no-output typechecks the ladder
# and this spec without writing a SWF or needing a player.
spec --swf "$test_source/spec.swf" --no-output

# A real AIR build is the Flash target plus `air`, which is exactly the case
# where two of the ladder's branches match at once; `detect()` must still pick
# AIR. That ordering is asserted on the interpreter above (`-D air --interp`,
# where the spec's `air` branch requires detect() == AIR); this SWF pass only
# type-checks the combined build, since a SWF cannot be executed on CI.
spec -D air --swf "$test_source/spec.swf" --no-output
