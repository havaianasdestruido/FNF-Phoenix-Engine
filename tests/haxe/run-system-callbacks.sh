#!/usr/bin/env bash
# Exercise SystemCallbacks, PySystemLib, and SystemInfo softmodding wiring.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/debug/system" "$work/psychlua/callbacks" "$work/psychlua/pystdlib"
cp "$root/source/debug/system/SystemInfo.hx" "$work/debug/system/"
cp "$root/source/psychlua/callbacks/SystemCallbacks.hx" "$work/psychlua/callbacks/"
cp "$root/source/psychlua/pystdlib/PySystemLib.hx" "$work/psychlua/pystdlib/"
cp -R "$root/tests/haxe/stubs/system/." "$work/"

haxe_bin="${HAXE:-haxe}"
"$haxe_bin" -cp "$work" -cp "$root/tests/haxe" -main SystemCallbacksSpec --interp

for pair in \
  "source/psychlua/FunkinLua.hx:SystemCallbacks.register(this)" \
  "source/psychlua/PythonScript.hx:PySystemLib.register(this)" \
  "source/psychlua/HScript.hx:SystemCallbacks.seedHScript(interp)" \
  "source/psychlua/HaxeScript.hx:SystemCallbacks.seedHScript(interp)"; do
  file="${pair%%:*}"
  needle="${pair#*:}"
  if ! grep -qF "$needle" "$root/$file"; then
    echo "run-system-callbacks: $file is missing \`$needle\`" >&2
    exit 1
  fi
done
echo "Lua / Python / HScript / HaxeScript system wiring: ok"
