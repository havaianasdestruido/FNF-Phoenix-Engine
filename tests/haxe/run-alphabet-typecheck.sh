#!/usr/bin/env bash
# Type check the alphabet renderer against the real Flixel/OpenFL/Lime sources.
#
# The glyph rasterizer needs openfl.text.TextField, openfl.display.BitmapData and the
# FlxGraphic cache, so -- unlike the other specs in this folder -- it cannot run on the
# Haxe interpreter with stubs. It compiles source/objects/Alphabet.hx,
# source/objects/AlphabetFont.hx and source/objects/AlphabetFontRenderer.hx unchanged,
# with renderer-free stubs only for Paths/ClientPrefs/ScreenLayout, for both the html5 and
# the native (cpp) targets.
#
# The libraries are found through `haxelib path` (what setup/windows.bat and hmm install)
# or through FLIXEL_PATH / OPENFL_PATH / LIME_PATH (and FLIXEL_ADDONS_PATH for the
# flixel-addons imports in source/import.hx). Without them the script skips, so it
# stays usable on a sandbox that only has the Haxe compiler.
#
# Shell only, unlike the other scripts here: it discovers the libraries at runtime and
# writes six stub sources, and it is not wired into CI (the Checks job has no game
# haxelibs, so it would only ever print SKIP). Use run-alphabet-font.bat/.ps1 for the
# renderer-free model tests on Windows.
set -euo pipefail
cd "$(dirname "$0")/../.."

# $1 haxelib name, $2 env var override, $3 package path inside the library when it is
# not the library name (flixel-addons ships flixel/addons).
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
# source/import.hx imports two flixel-addons types, so the global import list
# cannot resolve without the library. It is optional: it is only needed to make
# those two lines resolve, the alphabet files never use them.
addons=$(find_lib flixel-addons FLIXEL_ADDONS_PATH flixel/addons || true)

if [ -z "$flixel" ] || [ -z "$openfl" ] || [ -z "$lime" ]; then
  echo "SKIP: flixel/openfl/lime sources not found (haxelib path or FLIXEL_PATH/OPENFL_PATH/LIME_PATH)"
  exit 0
fi

test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/objects" "$test_source/backend" "$test_source/play"
cp source/objects/Alphabet.hx "$test_source/objects/Alphabet.hx"
cp source/objects/AlphabetFont.hx "$test_source/objects/AlphabetFont.hx"
cp source/objects/AlphabetFontRenderer.hx "$test_source/objects/AlphabetFontRenderer.hx"

# The engine's own global imports, copied verbatim. Do not hand write a subset
# here: a subset once listed flixel.graphics.FlxGraphic, which source/import.hx
# does not, so Alphabet.hx type checked here and died in the native build with
# "Type not found : FlxGraphic".
cp source/import.hx "$test_source/import.hx"
cp -r source/utils "$test_source/utils"

# Modules source/import.hx names that the alphabet files never touch. They are
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

cat > "$test_source/backend/ScreenLayout.hx" <<'HAXE'
package backend;

class ScreenLayout
{
  public static final BASE_WIDTH:Int = 1280;
}
HAXE

cat > "$test_source/backend/ClientPrefs.hx" <<'HAXE'
package backend;

class ClientPrefs
{
  public static var globalAntialiasing:Bool = true;
  public static var alphabetStyle:String = 'Font';
  public static var alphabetFont:String = 'VCR OSD Mono';
  public static var alphabetAntialiasing:Bool = true;
}
HAXE

cat > "$test_source/backend/Paths.hx" <<'HAXE'
package backend;

import flixel.graphics.frames.FlxAtlasFrames;

class Paths
{
  public static function image(key:String):Dynamic return 'assets/images/$key.png';
  public static function font(key:String):String return 'assets/fonts/$key';
  public static function getSparrowAtlas(key:String, ?library:String):FlxAtlasFrames return null;
}
HAXE

# Touches the public surface scripts and menus use: text rebuild, scaling, alignment,
# per letter color, the spritesheet override and the font cache entry points.
cat > "$test_source/TypecheckMain.hx" <<'HAXE'
import objects.Alphabet;
import objects.Alphabet.AlphaCharacter;
import objects.AlphabetFont;
import objects.AlphabetFontRenderer;

class TypecheckMain
{
  static function main():Void
  {
    var menu:Alphabet = new Alphabet(10, 20, 'Story Mode', true);
    menu.setScale(0.7);
    menu.setAlignmentFromString('center');
    menu.text = 'Second line\nwrapped text 1234';

    var line:Alphabet = new Alphabet(0, 300, 'dialogue text', false);
    line.scaleX = 1.2;
    var letter:AlphaCharacter = line.letters[0];
    letter.color = FlxColor.RED;
    letter.image = 'alphabetOld';
    line.snapToPosition();

    AlphabetFontRenderer.warmUp(AlphabetFont.currentFont());
    AlphabetFontRenderer.clearCache();
    Alphabet.reloadAll();
    trace(menu.letters.length, menu.rows, letter.fontGlyph, letter.forceImage);
  }
}
HAXE

common="-cp $test_source -cp $flixel -cp $openfl -cp $lime -D lime=8.1.2 -D openfl=9.3.0"
if [ -n "$addons" ]; then
  common="$common -cp $addons"
fi

echo "Typechecking the alphabet renderer for html5..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D html5 -D lime_html5 -D lime_webgl -D openfl_html5 -D webgl -D canvas -D dom \
  -main TypecheckMain -js "$test_source/alphabet.js" --no-output

echo "Typechecking the alphabet renderer for native..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D windows -D desktop -D native -D lime_native -D lime_opengl \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

echo "AlphabetFont typecheck: PASS"
