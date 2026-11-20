#!/usr/bin/env bash
# Type check the pointing-finger menu cursor against the real
# Flixel/OpenFL/Lime sources.
#
# `objects/PointingCursor.hx` reads the pointer the way the fix for the
# "main menu scrolls back up" bug needs: `FlxG.mouse.getScreenPosition(camera)`
# (the pointer in the members' camera space), `FlxG.game.mouseX/mouseY` (the
# raw position the movement gate compares, unaffected by camera pans and zoom
# pulses), `FlxSprite.scrollFactor`, `FlxObject.cameras` and
# `FlxCamera.scroll`. The pure math behind it is covered by
# run-pointing-cursor.sh; only the real libraries can prove those members
# exist with those types. This compiles the production overlay and its logic
# unchanged — plus the slice of `ClientPrefs` it reads — for html5, desktop
# without and with `lime_cffi`, and Android.
#
# Stubbed: `backend.ClientPrefs` (the real one drags in most of the engine;
# the stand-in keeps the three fields the overlay reads).
#
# The libraries are found through `haxelib path` (what setup/windows.bat and
# hmm install) or through FLIXEL_PATH / OPENFL_PATH / LIME_PATH. Without all
# three the script skips, so it stays usable on a sandbox that only has the
# Haxe compiler.
#
# Shell only, like the other *-typecheck scripts that need the game libraries:
# it discovers them at runtime and writes stub sources, and it is not wired
# into CI (the Checks job has no game haxelibs, so it would only ever print
# SKIP). Use run-pointing-cursor.sh for the renderer-free spec.
set -euo pipefail
cd "$(dirname "$0")/../.."

# $1 haxelib name, $2 env var override, $3 package path inside the library when
# it is not the library name (openfl and lime keep their classes under src/).
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

# The version haxelib would define for a library, read from its haxelib.json:
# Flixel compiles different code for different OpenFL releases, so the defines
# have to describe the sources that are actually on the class path.
lib_version() {
  local dir="$1" fallback="$2" file=""
  for file in "$dir/haxelib.json" "$dir/../haxelib.json"; do
    if [ -f "$file" ]; then
      sed -n 's/.*"version"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$file" | head -1
      return 0
    fi
  done
  printf '%s' "$fallback"
}

flixel=$(find_lib flixel FLIXEL_PATH || true)
openfl=$(find_lib openfl OPENFL_PATH || true)
lime=$(find_lib lime LIME_PATH || true)

if [ -z "$flixel" ] || [ -z "$openfl" ] || [ -z "$lime" ]; then
  echo "SKIP: flixel/openfl/lime sources not found (haxelib path or FLIXEL_PATH/OPENFL_PATH/LIME_PATH)"
  exit 0
fi

test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/objects"

# Production code, unchanged.
cp source/objects/PointingCursor.hx "$test_source/objects/"
cp source/backend/PointingCursorLogic.hx "$test_source/backend/"

# ---- the slice of the engine the overlay reads ---------------------------------

cat > "$test_source/backend/ClientPrefs.hx" <<'HAXE'
package backend;

/** Same names and types as the fields the overlay reads. */
class ClientPrefs
{
  public static var pointingCursor:Bool = true;
  public static var pointingCursorStyle:String = 'Finger';
  public static var pointingCursorColor:String = 'White';
}
HAXE

# Exercises both ways in: hosting a fresh overlay (attachAndFollow) and
# re-following an existing one, on members with a parallax scroll factor and
# an explicit camera, with a null hole in the list.
cat > "$test_source/TypecheckMain.hx" <<'HAXE'
import flixel.FlxG;
import flixel.FlxSprite;
import flixel.FlxState;
import objects.PointingCursor;

class TypecheckMain
{
  static function main():Void
  {
    final host:FlxState = new FlxState();
    final item:FlxSprite = new FlxSprite(332.5, -132 + 140);
    item.scrollFactor.set(0, 0.405);
    item.cameras = [FlxG.camera];
    final members:Array<FlxSprite> = [item, null];

    final cursor:PointingCursor = PointingCursor.attachAndFollow(host, null, members, 0);
    cursor.follow(members, 1);
    cursor.refreshAppearance();
    trace(cursor.selectionIndex, cursor.pointedIndex, cursor.visible);
  }
}
HAXE

# FlxDefines is what turns the absence of FLX_NO_TOUCH / FLX_NO_MOUSE / ... into
# FLX_TOUCH, FLX_MOUSE, FLX_KEYBOARD and FLX_GAMEPAD; include.xml runs it in a
# real build, so it has to run here for `FlxG.mouse` to exist.
common="-cp $test_source -cp $flixel -cp $openfl -cp $lime"
common="$common -D lime=$(lib_version "$lime" 8.1.2) -D openfl=$(lib_version "$openfl" 9.3.3)"
common="$common --macro flixel.system.macros.FlxDefines.run()"

echo "Typechecking the pointing cursor for html5..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D html5 -D lime_html5 -D lime_webgl -D openfl_html5 -D webgl -D canvas -D dom \
  -main TypecheckMain -js "$test_source/pointing-cursor.js" --no-output

echo "Typechecking the pointing cursor for native..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D windows -D desktop -D native -D lime_native -D lime_opengl \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

# Native builds define lime_cffi; the overlay must compile there too.
echo "Typechecking the pointing cursor for native with lime_cffi..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D windows -D desktop -D native -D lime_native -D lime_opengl -D lime_cffi \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

# `#if android`: the menus run there with a touch-synthesized mouse.
echo "Typechecking the pointing cursor for Android..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D android -D mobile -D native -D lime_native -D lime_opengl -D lime_opengles -D lime_cffi \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

echo "Pointing cursor typecheck: PASS"
