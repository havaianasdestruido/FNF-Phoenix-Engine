#!/usr/bin/env bash
# Exercise the real stdfire facade/bindings with small platform doubles. No game
# haxelibs are required; optional interpreter, C++ worker and Lua tests run
# when HSCRIPT_PATH, HYTHON_PATH and hxcpp/hxluajit are available.
set -euo pipefail
cd "$(dirname "$0")/../.."
root="$PWD"
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend" "$work/psychlua" "$work/android/platform" "$work/ios/platform"
cp source/backend/StdFire.hx source/backend/ScriptSecurityScanner.hx source/backend/ModSecurity.hx "$work/backend/"
cp source/psychlua/StdFireLibrary.hx "$work/psychlua/"
cp source/android/platform/AndroidStdFire.hx "$work/android/platform/"
cp source/ios/platform/IOSStdFire.hx "$work/ios/platform/"
stubs="$root/tests/haxe/stubs/stdfire"

"${HAXE:-haxe}" -cp "$work" -cp "$stubs" -cp tests/haxe -main StdFireSpec --interp
"${HAXE:-haxe}" -cp "$work" -cp "$stubs" -cp tests/haxe -D android -main StdFireSpec --interp
"${HAXE:-haxe}" -cp tests/haxe -main StdFireWiringSpec --interp
"${HAXE:-haxe}" -cp "$work" -cp "$stubs" -cp tests/haxe -D html5 -main StdFireBrowserSpec -js "$work/browser.js"
node "$work/browser.js"

# Typecheck all native-specific branches, including the Win32 and UIKit bridges.
for platform in windows linux mac android ios; do
  "${HAXE:-haxe}" -cp "$work" -cp "$stubs" -cp tests/haxe -D "$platform" -main StdFireSpec -cpp "$work/cpp-$platform" --no-output
done

if [[ -n "${HSCRIPT_PATH:-}" && -n "${HYTHON_PATH:-}" ]]; then
  "${HAXE:-haxe}" -cp "$work" -cp "$stubs" -cp tests/haxe -cp "$HSCRIPT_PATH" -cp "$HYTHON_PATH" \
    -main StdFireScriptingSpec --interp
  if [[ "${STDFIRE_TEST_CPP_INTERPRETERS:-0}" == 1 ]]; then
    "${HAXE:-haxe}" -cp "$work" -cp "$stubs" -cp tests/haxe -cp "$HSCRIPT_PATH" -cp "$HYTHON_PATH" \
      -D linux -main StdFireScriptingSpec -cpp "$work/interpreters"
    "$work/interpreters/StdFireScriptingSpec"
  fi
else
  echo 'SKIP: set HSCRIPT_PATH and HYTHON_PATH to run actual HScript/Hython integration'
fi

# Exercise the real C++ worker as well whenever hxcpp integration is requested.
if [[ "${STDFIRE_TEST_CPP:-0}" == 1 || "${STDFIRE_TEST_CPP_INTERPRETERS:-0}" == 1 || "${STDFIRE_TEST_LUA:-0}" == 1 ]]; then
  "${HAXE:-haxe}" -cp "$work" -cp "$stubs" -cp tests/haxe -D linux \
    -main StdFireDesktopWarnSpec -cpp "$work/desktop-warning"
  "$work/desktop-warning/StdFireDesktopWarnSpec"
else
  echo 'SKIP: set STDFIRE_TEST_CPP=1 with hxcpp installed for the non-blocking desktop warning test'
fi

# Optional real LuaJIT+hxcpp integration, including production Convert.hx.
if [[ "${STDFIRE_TEST_LUA:-0}" == 1 ]]; then
  cp source/psychlua/Convert.hx source/psychlua/LuaFunction.hx "$work/psychlua/"
  # Convert uses the engine's global Lua imports from source/import.hx.
  printf 'import hxluajit.*;\nimport hxluajit.Types;\n' > "$work/import.hx"
  "${HAXE:-haxe}" -cp "$work" -cp "$stubs" -cp tests/haxe -lib hxluajit -D LUA_ALLOWED -D linux \
    -main StdFireLuaSpec -cpp "$work/lua"
  "$work/lua/StdFireLuaSpec"
else
  echo 'SKIP: set STDFIRE_TEST_LUA=1 with hxcpp and hxluajit installed for real LuaJIT integration'
fi
