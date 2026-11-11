#!/usr/bin/env bash
# Contract tests for backend.LuaDiagnostics: what the engine says, and when,
# about a Lua script that does not load or whose hooks do not run
# (docs/LUA_SCRIPT_DEBUGGING.md).
#
# source/backend/LuaDiagnostics.hx is deliberately dependency free, so this runs
# with nothing but Haxe. The spec also reads the engine sources as data to check
# that the loader still feeds the diagnostics.
#
# Point LUAJIT at a LuaJIT binary to also check the error-position rules against
# messages produced by the real runtime:
#
#   LUAJIT=/path/to/luajit bash tests/haxe/run-lua-diagnostics.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend"
cp source/backend/LuaDiagnostics.hx "$test_source/backend/LuaDiagnostics.hx"
export LUA_DIAGNOSTICS_TMP="$test_source"

if [ -n "${LUAJIT:-}" ] && ! command -v "$LUAJIT" >/dev/null 2>&1; then
  echo "NOTE: LUAJIT=$LUAJIT is not executable; skipping the real-runtime checks"
  export LUAJIT=""
fi

spec() {
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main LuaDiagnosticsSpec "$@" --interp
}

# No define: a target that cannot include Lua (mobile, web).
spec

# A desktop build without the Lua VM: .lua files are found but cannot run.
spec -D desktop

# A desktop build with the Lua VM.
spec -D desktop -D LUA_ALLOWED
