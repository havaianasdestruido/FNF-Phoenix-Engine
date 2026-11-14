#!/usr/bin/env bash
# Typecheck the real adapter against Flixel/OpenFL/Lime. The full PlayState is
# replaced with its relevant real-typed surface; no game assets are needed.
set -euo pipefail
cd "$(dirname "$0")/../.."
find_lib() {
  local name="$1" envvar="$2" dir=""
  if [ -n "${!envvar:-}" ]; then dir="${!envvar}"
  elif command -v haxelib >/dev/null 2>&1; then dir=$(haxelib path "$name" 2>/dev/null | head -1 || true)
  fi
  [ -z "$dir" ] && return 1
  if [ -d "$dir/src/$name" ]; then printf '%s' "$dir/src"
  elif [ -d "$dir/$name" ]; then printf '%s' "$dir"
  else return 1
  fi
}
flixel=$(find_lib flixel FLIXEL_PATH || true)
openfl=$(find_lib openfl OPENFL_PATH || true)
lime=$(find_lib lime LIME_PATH || true)
if [ -z "$flixel" ] || [ -z "$openfl" ] || [ -z "$lime" ]; then
  echo 'SKIP: real flixel/openfl/lime sources not found'
  exit 0
fi
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/play/helpers" "$work/backend" "$work/debug" "$work/objects"
cp source/play/helpers/{AdaptivePerformance,PlayStateAdaptivePerformance}.hx "$work/play/helpers/"
cp tests/haxe/stubs/adaptive-performance/backend/{ClientPrefs,Paths,ScreenLayout,VLog}.hx "$work/backend/"
cp tests/haxe/stubs/adaptive-performance/debug/FrameProfiler.hx "$work/debug/"
cat > "$work/objects/Popup.hx" <<'HAXE'
package objects;
class Popup extends flixel.FlxSprite
{
  public var isRatingPopup(default, null):Bool = false;
}
HAXE
cat > "$work/play/PlayState.hx" <<'HAXE'
package play;
import flixel.FlxCamera;
import flixel.FlxSprite;
import flixel.FlxState;
import flixel.group.FlxGroup.FlxTypedGroup;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.text.FlxText;
import flixel.util.FlxTimer;
import objects.Popup;
class PlayState extends FlxState
{
  var startedCountdown:Bool = true;
  public var startingSong:Bool = false;
  public var endingSong:Bool = false;
  public var inCutscene:Bool = false;
  public var paused:Bool = false;
  public var isDead:Bool = false;
  public var transitioning:Bool = false;
  var finishTimer:FlxTimer = null;
  var ffmpegMode:Bool = false;
  public var camOther:FlxCamera;
  public var grpNoteSplashes:FlxTypedGroup<FlxSprite>;
  public var grpHoldSplashes:FlxTypedGroup<FlxSprite>;
  public var popUpGroup:FlxTypedSpriteGroup<Popup>;
  public var timingGroup:FlxTypedSpriteGroup<FlxSprite>;
  public var judgeTxt:FlxText;
}
HAXE
cat > "$work/TypecheckAdaptive.hx" <<'HAXE'
import play.PlayState;
import play.helpers.PlayStateAdaptivePerformance;
class TypecheckAdaptive
{
  static function main():Void
  {
    final adapter = new PlayStateAdaptivePerformance(new PlayState());
    adapter.setFocused(false);
    adapter.repositionNotice();
    adapter.destroy();
  }
}
HAXE
common=(-cp "$work" -cp "$flixel" -cp "$openfl" -cp "$lime" -D lime=8.1.2 -D openfl=9.3.0)
echo 'Typechecking adaptive performance against real Flixel/OpenFL/Lime (native + browser)...'
"${HAXE:-haxe}" "${common[@]}" -D windows -D desktop -D native -D lime_native -D lime_opengl \
  -main TypecheckAdaptive -cpp "$work/cpp" --no-output
"${HAXE:-haxe}" "${common[@]}" -D html5 -D web -D lime_webgl \
  -main TypecheckAdaptive -js "$work/browser.js" --no-output
echo 'Adaptive performance typecheck: PASS'

# Exercise the production adapter with a real OpenFL System.gc(); only the
# Flixel/game objects are doubled. Neko is quick; hxcpp is explicitly opt-in
# because compiling its runtime can take several minutes.
smoke="$work/native-smoke"
mkdir -p "$smoke/play/helpers"
cp -r tests/haxe/stubs/adaptive-performance/. "$smoke/"
rm "$smoke/openfl/system/System.hx"
cp source/play/helpers/{AdaptivePerformance,PlayStateAdaptivePerformance}.hx "$smoke/play/helpers/"
smoke_common=(-cp "$openfl" -cp "$lime" -cp "$smoke" -cp tests/haxe
  -D lime=8.1.2 -D openfl=9.3.0 -main AdaptivePerformanceNativeSmoke)
if command -v neko >/dev/null 2>&1; then
  "${HAXE:-haxe}" "${smoke_common[@]}" -neko "$work/adaptive-neko.n"
  neko "$work/adaptive-neko.n"
else
  echo 'SKIP: Neko runtime GC smoke (neko executable not found)'
fi
if [ "${ADAPTIVE_HXCPP_SMOKE:-0}" = 1 ]; then
  echo 'Building the optional hxcpp runtime GC smoke (this can take several minutes)...'
  "${HAXE:-haxe}" "${smoke_common[@]}" -cpp "$work/hxcpp-smoke"
  executable="$work/hxcpp-smoke/AdaptivePerformanceNativeSmoke"
  if [ ! -f "$executable" ] && [ -f "$executable.exe" ]; then executable="$executable.exe"; fi
  "$executable"
fi
