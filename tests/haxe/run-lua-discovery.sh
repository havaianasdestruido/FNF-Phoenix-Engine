#!/usr/bin/env bash
#
# Dynamic tests for the Lua script pipeline: does a `.lua` mod script get
# discovered, survive the ModSecurity source gate, and actually execute under
# the sandbox bootstrap the engine installs?
#
# Stages 1-2 (discovery + source gate) are pure Haxe and run everywhere. The
# interpreter half (stage 3-4) needs a LuaJIT, because that is the runtime
# hxluajit binds; point LUAJIT at one to enable it:
#
#   LUAJIT=/path/to/luajit bash tests/haxe/run-lua-discovery.sh
#
# Only source/backend/ModSecurity.hx and ScriptSecurityScanner.hx are pulled in
# (they are dependency free); the specs read the rest of the tree as data.
set -euo pipefail
cd "$(dirname "$0")/../.."
repo="$PWD"

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/backend"
cp source/backend/ModSecurity.hx "$work/backend/ModSecurity.hx"
cp source/backend/ScriptSecurityScanner.hx "$work/backend/ScriptSecurityScanner.hx"

if [ -n "${LUAJIT:-}" ] && ! command -v "$LUAJIT" >/dev/null 2>&1; then
  echo "NOTE: LUAJIT=$LUAJIT is not executable; running the Haxe-only stages"
  export LUAJIT=""
fi

# The spec walks the repository (mods/, docs/, source/) relative to the game
# root, so it has to run from there -- but with a throwaway output directory.
"${HAXE:-haxe}" -cp "$work" -cp "$repo/tests/haxe" -main LuaScriptDiscoverySpec --interp
