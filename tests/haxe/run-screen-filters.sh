#!/usr/bin/env bash
# Plain (non-shader) filters and flixel-addons chainable effects in the script
# API, run on the Haxe interpreter against recording stubs of the OpenFL filter
# classes and the addon's effect classes. No game haxelibs, no GPU.
#
# Two specs:
#   ScreenFiltersSpec   - backend/ScreenFilters + backend/ChainableEffects
#   FlxGameFiltersSpec  - the `FlxG.game.filters` patch surface (a mirror class,
#                         because FlxGame itself imports the whole engine; the
#                         declarations are checked against the patch file below)
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT

mkdir -p "$work/backend"
cp "$root/source/backend/ScreenFilters.hx" "$work/backend/"
cp "$root/source/backend/ChainableEffects.hx" "$work/backend/"
cp -R "$root/tests/haxe/stubs/screen-filters/." "$work/"

haxe_bin="${HAXE:-haxe}"
"$haxe_bin" -cp "$work" -cp "$root/tests/haxe" -main ScreenFiltersSpec --interp
"$haxe_bin" -cp "$work" -cp "$root/tests/haxe" -main FlxGameFiltersSpec --interp

# The mirror above only proves the behaviour; this proves the real patch still
# has it (a rebase onto a newer flixel silently drops the override otherwise).
patch_file="$root/source/source-haxelib-patches/flixel/FlxGame.hx"
for needle in \
  'override function get_filters():Array<BitmapFilter>' \
  'override function set_filters(Value:Array<BitmapFilter>):Array<BitmapFilter>' \
  'public function applyGameFiltersNow():Void' \
  'this.filters = filters;' \
  'applyGameFiltersNow();'; do
  if ! grep -qF "$needle" "$patch_file"; then
    echo "run-screen-filters: $patch_file lost \`$needle\`" >&2
    exit 1
  fi
done
echo "FlxGame patch: ok"

# One `api()` builds the surface for all three hosts, so a host that forgets to
# bind it would silently lose the whole feature in that language only.
for pair in \
  "source/psychlua/FunkinLua.hx:FilterCallbacks.register(this)" \
  "source/psychlua/PythonScript.hx:PyFilterLib.register(this)" \
  "source/psychlua/HScript.hx:FilterCallbacks.seedHScript(interp)"; do
  file="${pair%%:*}"
  needle="${pair#*:}"
  if ! grep -qF "$needle" "$root/$file"; then
    echo "run-screen-filters: $file no longer binds the filter API (\`$needle\`)" >&2
    exit 1
  fi
done
echo "Lua / Python / HScript wiring: ok"
