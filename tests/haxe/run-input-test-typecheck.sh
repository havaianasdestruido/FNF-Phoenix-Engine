#!/usr/bin/env bash
# Type check the input tester page (`phoenix://input`) against the real
# Flixel/OpenFL/Lime sources.
#
# `states/InputTestState.hx` reads the real input managers: `FlxG.gamepads`
# (`getByID`, `checkStatus`, `getInputLabel`), `FlxG.touches.list` and each
# touch's `touchPointID` / `screenX`, `FlxG.mouse`, the stage's `KeyboardEvent`s,
# `FlxState.onFocusLost`, `FlxG.sound.muteKeys` and Lime's performance counter.
# The stubs behind run-input-test.sh prove what the page *does* with them; only
# the real libraries can prove those members exist with those types. This
# compiles the production page and its model unchanged, together with the real
# `InputFormatter`, `HardwareKeys`, `HoldToConfirmLogic`, `ScreenLayout`,
# `ViewportVisuals`, `TouchlessUI` and `AndroidTVPolicy`, four times: html5 (the
# browser clock), desktop without and with `lime_cffi` (the two native clocks)
# and Android (the system Back button, `FlxG.android`).
#
# Stubbed: `MusicBeatState` (the real one pulls in PlayState and with it the whole
# engine; the stand-in keeps the members the page touches on a real `FlxState`),
# the states the page leaves to, and the slice of `ClientPrefs` / `Paths` it reads.
#
# The libraries are found through `haxelib path` (what setup/windows.bat and hmm
# install) or through FLIXEL_PATH / OPENFL_PATH / LIME_PATH / FLIXEL_ADDONS_PATH
# (flixel-addons only for the imports in source/import.hx). Without all four the
# script skips, so it stays usable on a sandbox that only has the Haxe compiler.
#
# Shell only, like the other *-typecheck scripts that need the game libraries: it
# discovers them at runtime and writes stub sources, and it is not wired into CI
# (the Checks job has no game haxelibs, so it would only ever print SKIP). Use
# run-input-test.bat/.ps1 for the renderer-free specs on Windows.
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
# source/import.hx imports two flixel-addons types, so the global import list
# cannot resolve without the library. The page itself never uses them.
addons=$(find_lib flixel-addons FLIXEL_ADDONS_PATH flixel/addons || true)

if [ -z "$flixel" ] || [ -z "$openfl" ] || [ -z "$lime" ]; then
  echo "SKIP: flixel/openfl/lime sources not found (haxelib path or FLIXEL_PATH/OPENFL_PATH/LIME_PATH)"
  exit 0
fi
if [ -z "$addons" ]; then
  echo "SKIP: flixel-addons sources not found (haxelib path or FLIXEL_ADDONS_PATH); source/import.hx imports them"
  exit 0
fi

test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/states" "$test_source/options" "$test_source/mobile" "$test_source/play" \
  "$test_source/android/platform"

# Production code, unchanged.
cp source/states/InputTestState.hx "$test_source/states/"
for module in InputTestLogic InputFormatter HardwareKeys HoldToConfirmLogic ScreenLayout ViewportVisuals TouchlessUI AndroidTVPolicy; do
  cp "source/backend/$module.hx" "$test_source/backend/"
done

# What TouchlessUI subscribes to on Android; only the Android pass reads them.
cp source/android/platform/AndroidBridge.hx source/android/platform/AndroidSystem.hx "$test_source/android/platform/"

# The engine's own global imports, copied verbatim (see run-alphabet-typecheck.sh
# for why the list is not trimmed to what this page uses today).
cp source/import.hx "$test_source/import.hx"
cp -r source/utils "$test_source/utils"

# ---- modules source/import.hx names that the page never touches -------------

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

# ---- the slice of the engine the page reads ---------------------------------

cat > "$test_source/backend/ClientPrefs.hx" <<'HAXE'
package backend;

import flixel.input.keyboard.FlxKey;

/** Same names and types as the fields the page and its helpers read. */
class ClientPrefs
{
  public static var globalAntialiasing:Bool = true;
  public static var androidTVNavigation:Bool = false;
  public static var uiScalePercent:Int = 100;
  public static var keyBinds:Map<String, Array<FlxKey>> = ['back' => [BACKSPACE, ESCAPE]];
}
HAXE

cat > "$test_source/backend/Paths.hx" <<'HAXE'
package backend;

class Paths
{
  public static function image(key:String, ?library:String):Dynamic return 'assets/images/$key.png';
  public static function font(key:String):String return 'assets/fonts/$key';
  public static function sound(key:String, ?library:String):Dynamic return 'assets/sounds/$key.ogg';
}
HAXE

# The real base state is a FlxUIState that imports PlayState; this keeps the
# members InputTestState uses, with the real signatures, on a real FlxState.
cat > "$test_source/backend/MusicBeatState.hx" <<'HAXE'
package backend;

import flixel.FlxState;

class MusicBeatState extends FlxState
{
  public static var windowNameSuffix(default, set):String = "";

  static function set_windowNameSuffix(value:String)
  {
    windowNameSuffix = value;
    return value;
  }

  public function new()
  {
    super();
  }

  override function create()
  {
    super.create();
  }

  override function update(elapsed:Float)
  {
    super.update(elapsed);
  }

  override function destroy():Void
  {
    super.destroy();
  }
}
HAXE

cat > "$test_source/states/MainMenuState.hx" <<'HAXE'
package states;

class MainMenuState extends backend.MusicBeatState
{
}
HAXE

cat > "$test_source/states/TitleState.hx" <<'HAXE'
package states;

import flixel.input.keyboard.FlxKey;

class TitleState extends backend.MusicBeatState
{
  public static var muteKeys:Array<FlxKey> = [FlxKey.ZERO];
  public static var volumeDownKeys:Array<FlxKey> = [FlxKey.NUMPADMINUS, FlxKey.MINUS];
  public static var volumeUpKeys:Array<FlxKey> = [FlxKey.NUMPADPLUS, FlxKey.PLUS];
}
HAXE

cat > "$test_source/options/OptionsState.hx" <<'HAXE'
package options;

class OptionsState extends backend.MusicBeatState
{
  public function new(openMisc:Bool = false)
  {
    super();
  }
}
HAXE

cat > "$test_source/mobile/MobileControls.hx" <<'HAXE'
package mobile;

class MobileControls
{
  public static var enabled(get, never):Bool;

  static function get_enabled():Bool
    return backend.AndroidTVPolicy.shouldShowTouchControls(backend.ClientPrefs.androidTVNavigation, 0.6);
}
HAXE

# Both ways in: the deep link (Main Menu on Back) and the Options entry.
cat > "$test_source/TypecheckMain.hx" <<'HAXE'
import backend.InputTestLogic;
import flixel.FlxG;
import states.InputTestState;

class TypecheckMain
{
  static function main():Void
  {
    FlxG.switchState(() -> new InputTestState());
    FlxG.switchState(() -> new InputTestState(true));
    trace(InputTestLogic.formatMs(16.7), new InputTestLogic().counters(InputTestLogic.TOUCH));
  }
}
HAXE

# FlxDefines is what turns the absence of FLX_NO_TOUCH / FLX_NO_MOUSE / ... into
# FLX_TOUCH, FLX_MOUSE, FLX_KEYBOARD and FLX_GAMEPAD; include.xml runs it in a
# real build, so it has to run here for `FlxG.touches` and friends to exist.
common="-cp $test_source -cp $flixel -cp $openfl -cp $lime"
common="$common -D lime=$(lib_version "$lime" 8.1.2) -D openfl=$(lib_version "$openfl" 9.3.3)"
common="$common --macro flixel.system.macros.FlxDefines.run()"
common="$common -cp $addons -D flixel-addons=$(lib_version "$addons" 3.2.3)"

echo "Typechecking the input tester for html5..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D html5 -D lime_html5 -D lime_webgl -D openfl_html5 -D webgl -D canvas -D dom \
  -main TypecheckMain -js "$test_source/input-test.js" --no-output

echo "Typechecking the input tester for native..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D windows -D desktop -D native -D lime_native -D lime_opengl \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

# Native builds define lime_cffi, which selects the high resolution clock.
echo "Typechecking the input tester for native with lime_cffi..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D windows -D desktop -D native -D lime_native -D lime_opengl -D lime_cffi \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

# `#if android`: the page leaves at once on the system Back button.
echo "Typechecking the input tester for Android..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D android -D mobile -D native -D lime_native -D lime_opengl -D lime_opengles -D lime_cffi \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

echo "InputTest typecheck: PASS"
