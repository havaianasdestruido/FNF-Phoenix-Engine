#!/usr/bin/env bash
# Platform gating contract: target/family/capability tags, requirement lists,
# aliases and the ClientPrefs / pack.json registries that Options, the save file
# and mod loading share.
#
# backend/PlatformSupport.hx is deliberately free of Flixel/OpenFL/Lime imports
# (it only reads compile-time defines), so this runs with nothing but Haxe.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/PlatformIcons.hx "$test_source/backend/PlatformIcons.hx"
cp source/backend/PlatformSupport.hx "$test_source/backend/PlatformSupport.hx"

spec() {
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main PlatformSupportSpec "$@"
}

# No target define: host/`sys` fallback.
spec --interp

for platform in windows mac linux android ios html5 air; do
  spec -D "$platform" --interp
done

# `flash` is a reserved compiler flag, so the Flash branch cannot be faked with
# -D: compile for the real target instead. --no-output typechecks the tag ladder
# and this spec without writing a SWF or needing a player.
spec --swf "$test_source/spec.swf" --no-output

# A real AIR build is the Flash target plus `air`; make sure the combined build
# typechecks (the interpreter run above asserts AIR wins over Flash).
spec -D air --swf "$test_source/spec.swf" --no-output
