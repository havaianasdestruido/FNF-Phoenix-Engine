#!/usr/bin/env bash
# Exercise the actual project.hxp against installed Lime and hxp, without the
# game's other haxelibs or a native compiler. Keep the shell variants in sync.
set -euo pipefail
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp project.hxp "$work/Project.hx"
"${HAXE:-haxe}" -lib lime -lib hxp -cp "$work" -cp tests/haxe -main ProjectBuildCacheSpec --interp
