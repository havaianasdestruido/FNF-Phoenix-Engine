#!/usr/bin/env bash
# Type check the distant-note shader effect against the real Flixel/OpenFL/Lime
# sources.
#
# `shaders.DistantNoteShader` declares its uniforms in GLSL and then touches the
# `uPivot`/`uSpread`/`uDownscroll` fields the OpenFL shader macro generates from
# `@:glFragmentSource`, so -- like the alphabet renderer -- it cannot be checked
# against stubs: a stub without those fields would accept code the real build
# rejects, and a stub with them would hide a typo in the GLSL uniform names. This
# compiles `source/shaders/{Effect,DistantNoteShader,DistantNoteEffect}.hx`
# unchanged, with the engine's real `import.hx` and renderer-free stubs only for
# Paths/Mods/BaseStage, for both the html5 and the native (cpp) targets.
#
# The libraries are found through `haxelib path` (what setup/windows.bat and hmm
# install) or through FLIXEL_PATH / OPENFL_PATH / LIME_PATH (and
# FLIXEL_ADDONS_PATH for the flixel-addons imports in source/import.hx). Without
# them the script skips, so it stays usable on a sandbox that only has the Haxe
# compiler.
#
# Shell only, unlike the other scripts here: it discovers the libraries at
# runtime and writes stub sources, and it is not wired into CI (the Checks job
# has no game haxelibs, so it would only ever print SKIP).
set -euo pipefail
cd "$(dirname "$0")/../.."

# $1 haxelib name, $2 env var override, $3 package path inside the library when
# it is not the library name (flixel-addons ships flixel/addons).
find_lib() {
  local name="$1" envvar="$2" pkg="${3:-$1}" dir=""
  if [ -n "${!envvar:-}" ]; then
    dir="${!envvar}"
  elif command -v haxelib >/dev/null 2>&1; then
    dir=$(haxelib path "$name" 2>/dev/null | head -1 || true)
  fi
  [ -z "$dir" ] && return 1
  # haxelib reports the library root; openfl and lime keep their classes under src/.
  if [ -d "$dir/src/$pkg" ]; then
    printf '%s' "$dir/src"
  elif [ -d "$dir/$pkg" ]; then
    printf '%s' "$dir"
  else
    return 1
  fi
}

flixel=$(find_lib flixel FLIXEL_PATH || true)
openfl=$(find_lib openfl OPENFL_PATH || true)
lime=$(find_lib lime LIME_PATH || true)
addons=$(find_lib flixel-addons FLIXEL_ADDONS_PATH flixel/addons || true)

if [ -z "$flixel" ] || [ -z "$openfl" ] || [ -z "$lime" ]; then
  echo "SKIP: flixel/openfl/lime sources not found (haxelib path or FLIXEL_PATH/OPENFL_PATH/LIME_PATH)"
  exit 0
fi

test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/shaders" "$test_source/backend" "$test_source/play"
cp source/shaders/Effect.hx "$test_source/shaders/"
cp source/shaders/DistantNoteShader.hx "$test_source/shaders/"
cp source/shaders/DistantNoteEffect.hx "$test_source/shaders/"

# The engine's own global imports, copied verbatim (see run-alphabet-typecheck.sh
# for why the list is not trimmed to what these files use today).
cp source/import.hx "$test_source/import.hx"
cp -r source/utils "$test_source/utils"

# Modules source/import.hx names that the shader files never touch. They are
# stubbed instead of pulled in, so the import list above stays the real one.
cat > "$test_source/play/BaseStage.hx" <<'HAXE'
package play;

enum Countdown
{
  THREE;
  TWO;
  ONE;
  GO;
  START;
}

class BaseStage
{
}
HAXE

cat > "$test_source/backend/ModsList.hx" <<'HAXE'
package backend;

class ModsList
{
}
HAXE

cat > "$test_source/backend/ModsStub.hx" <<'HAXE'
package backend;

class ModsStub
{
}
HAXE

cat > "$test_source/backend/Paths.hx" <<'HAXE'
package backend;

class Paths
{
  public static function image(key:String):Dynamic return 'assets/images/$key.png';
}
HAXE

# Touches the public surface mods drive: construction, every tunable, and the
# raw shader class HScript users may take from the effect.
cat > "$test_source/TypecheckMain.hx" <<'HAXE'
import shaders.DistantNoteEffect;
import shaders.DistantNoteShader;

class TypecheckMain
{
  static function main():Void
  {
    var guitar:DistantNoteEffect = new DistantNoteEffect(true, 0.42, 0.8);
    guitar.downscroll = false;
    guitar.pivot = 0.5;
    guitar.spread = 1.0;

    var raw:DistantNoteShader = guitar.shader;
    trace(guitar.downscroll, guitar.pivot, guitar.spread, raw != null);
  }
}
HAXE

common="-cp $test_source -cp $flixel -cp $openfl -cp $lime -D lime=8.1.2 -D openfl=9.3.0"
if [ -n "$addons" ]; then
  common="$common -cp $addons"
fi

echo "Typechecking the distant note effect for html5..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D html5 -D lime_html5 -D lime_webgl -D openfl_html5 -D webgl -D canvas -D dom \
  -main TypecheckMain -js "$test_source/distant.js" --no-output

echo "Typechecking the distant note effect for native..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D windows -D desktop -D native -D lime_native -D lime_opengl \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

echo "DistantNote typecheck: PASS"
