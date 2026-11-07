#!/usr/bin/env bash
# Exercise the real project.hxp and Android manifest template against installed
# Lime and hxp, without the game's other haxelibs or the Android SDK.
set -euo pipefail
cd "$(dirname "$0")/../.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
cp project.hxp "$work/Project.hx"
"${HAXE:-haxe}" -lib lime -lib hxp -cp "$work" -cp tests/haxe -main AndroidPermissionPolicySpec --interp
