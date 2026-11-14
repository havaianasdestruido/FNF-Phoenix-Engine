#!/usr/bin/env bash
# Type check the Mic'd Up! Early/Late rendering classes against the real
# Flixel/OpenFL/Lime sources.
#
# `objects/TimingPopup`, `objects/Popup`, `play/objects/JudgeText` and
# `play/helpers/PlayStateRating` call real renderer APIs
# (`FlxTypedSpriteGroup.recycle`, `FlxSprite.loadGraphic`, `FlxTween.tween`,
# `screenCenter`, `updateHitbox`, ...), so stubs would accept code the real build
# rejects. This compiles those production files unchanged, together with
# `play/helpers/HitTiming` and `play/objects/MissCounter`, plus a tiny main that
# drives them, for the native (cpp) target.
#
# `PlayState` itself is still stubbed (it is thousands of lines of engine), but the
# stub is generated from the real class: every member `PlayStateRating` touches is
# a real signature copied from source/play/PlayState.hx, so the helper is checked
# against the API it will actually call. What this cannot prove — that a note hit
# ends up labelled Early rather than Late — is asserted directly by
# tests/haxe/run-hit-timing.sh, which needs no libraries at all.
#
# The libraries are found through `haxelib path` or through FLIXEL_PATH /
# OPENFL_PATH / LIME_PATH (FLIXEL_ADDONS_PATH for the flixel-addons imports in
# source/import.hx). Without them the script skips, so it stays usable on a
# sandbox that only has the Haxe compiler, and — like
# run-distant-note-typecheck.sh — it is not wired into CI.
#
# KNOWN UPSTREAM BREAK: lime 8.1.x `lime/_internal/macros/AssetsMacro.hx` emits
# `super(bytes.length, bytes.b)` for the C++ target, and Haxe 5 rejects that
# ("Too many arguments" + "Missing super constructor call") while building any
# Lime asset class. It is a Lime bug, not a Phoenix one, so instead of patching
# the installed haxelib this script compiles a one-line shim of that single macro
# file on top of the library when it sees the pattern under Haxe 5. The shim is
# typecheck-only (`--no-output`), so the shortened `super` is never run. On Haxe 4
# the original file is used untouched.
set -euo pipefail
cd "$(dirname "$0")/../.."

# $1 haxelib name, $2 env var override, $3 package path inside the library when
# it is not the library name.
find_lib() {
  local name="$1" envvar="$2" pkg="${3:-$1}" dir=""
  if [ -n "${!envvar:-}" ]; then
    dir="${!envvar}"
  elif command -v haxelib >/dev/null 2>&1; then
    dir=$(haxelib path "$name" 2>/dev/null | head -1 || true)
  fi
  [ -z "$dir" ] && return 1
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

# See "KNOWN UPSTREAM BREAK" above: keep the Lime macro workaround out of the
# installed haxelib and apply it only where it is needed.
lime_shim=""
lime_macro="$lime/lime/_internal/macros/AssetsMacro.hx"
haxe_version=$("${HAXE:-haxe}" -version 2>/dev/null || true)
case "$haxe_version" in
  5.*)
    if [ -f "$lime_macro" ] && grep -q 'super(bytes.length, bytes.b)' "$lime_macro"; then
      mkdir -p "$test_source/lime_shim/lime/_internal/macros"
      sed 's/super(bytes\.length, bytes\.b)/super(bytes.length)/' "$lime_macro" \
        > "$test_source/lime_shim/lime/_internal/macros/AssetsMacro.hx"
      lime_shim="$test_source/lime_shim"
      echo "note: applying the lime AssetsMacro shim for Haxe $haxe_version"
    fi
    ;;
esac
mkdir -p "$test_source/psychlua" "$test_source/objects" "$test_source/backend" "$test_source/play/helpers" "$test_source/play/objects" "$test_source/debug" "$test_source/data"

cp source/play/helpers/HitTiming.hx "$test_source/play/helpers/"
cp source/play/objects/MissCounter.hx "$test_source/play/objects/"
cp source/play/objects/JudgeText.hx "$test_source/play/objects/"
cp source/objects/TimingPopup.hx "$test_source/objects/"
cp source/objects/Popup.hx "$test_source/objects/"
cp source/debug/PoolStats.hx "$test_source/debug/"
cp source/play/helpers/PlayStateRating.hx "$test_source/play/helpers/"
cp source/play/objects/MSText.hx "$test_source/play/objects/"

# The engine's own global imports (see run-alphabet-typecheck.sh for why the list
# is not trimmed to what these files use today).
cp source/import.hx "$test_source/import.hx"
cp -r source/utils "$test_source/utils"

# ---- stubs for engine modules the ported files name -------------------------

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

cat > "$test_source/backend/ClientPrefs.hx" <<'HAXE'
package backend;

class ClientPrefs
{
  public static var ratingPopups:Bool = true;
  public static var comboPopups:Bool = true;
  public static var comboStacking:Bool = true;
  public static var missRating:Bool = false;
  public static var doidoMisses:Bool = true;
  public static var simplePopups:Bool = false;
  public static var hideHud:Bool = false;
  public static var showMS:Bool = false;
  public static var globalAntialiasing:Bool = true;
  public static var earlyLateRatings:Bool = false;
  public static var earlyLateDeadzone:Float = 0.1;
  public static var comboOffset:Array<Int> = [0, 0, 0, 0];
  public static var downScroll:Bool = false;
  public static var scoreStyle:String = 'Psych Engine';
  public static var botWatermark:Bool = true;
  public static var cacheOnGPU:Bool = false;
  public static var lowQuality:Bool = false;
  public static var shaders:Bool = true;
  public static var showNPS:Bool = false;
  public static var showComboInfo:Bool = true;
  public static var ffmpegMode:Bool = false;
  public static var sickWindow:Float = 45;
  public static var ratingOffset:Int = 0;
  public static var ratingType:String = 'Default';
  public static var noMarvJudge:Bool = false;
  public static var complexAccuracy:Bool = false;
}
HAXE

cat > "$test_source/backend/Conductor.hx" <<'HAXE'
package backend;

class Conductor
{
  public static var songPosition:Float = 0;
  public static var safeZoneOffset:Float = 180;
  public static var timeScale:Float = 1;

  public static function judgeNote(note:Dynamic, diff:Float = 0, ?botplay:Bool = false, ?missedNote:Bool = false):Rating
    return new Rating('sick');
}

class Rating
{
  public var name:String = '';
  public var image:String = '';
  public var counter:String = '';
  public var hitWindow:Null<Float> = 0.0;
  public var ratingMod:Float = 1;
  public var score:Int = 500;
  public var noteSplash:Bool = true;

  public function new(name:String)
  {
    this.name = name;
    this.image = name;
  }

  public static function loadDefault():Array<Rating> return [];

  public function increase(blah:Int = 1):Void {}
}
HAXE

cat > "$test_source/backend/Paths.hx" <<'HAXE'
package backend;

class Paths
{
  public static function image(key:String):Dynamic return null;
  public static function font(key:String):String return 'assets/fonts/$key';
  /** Only the early art exists, so a missing label can be exercised too. */
  public static function imageExists(key:String, ?folder:String):Bool return key == 'ratings/default/early';
  public static function fileExists(key:String, ?type:Dynamic, ?ignoreMods:Bool = false):Bool return false;
}
HAXE

cat > "$test_source/backend/ScreenLayout.hx" <<'HAXE'
package backend;

class ScreenLayout
{
  public static inline var BASE_WIDTH:Int = 1280;
  public static inline var BASE_HEIGHT:Int = 720;
  public static inline function contentLeft(viewportWidth:Int):Float return 0;
  public static inline function fontScaled(size:Int):Int return size;
}
HAXE

cat > "$test_source/objects/Note.hx" <<'HAXE'
package objects;

import flixel.FlxSprite;

class Note extends FlxSprite
{
  public var strumTime:Float = 0;
  public var rating:String = 'unknown';
  public var ratingMod:Float = 0;
  public var hitTiming:String = '';
  public var ratingDisabled:Bool = false;
  public var noteSplashDisabled:Bool = false;
}
HAXE

cat > "$test_source/data/Song.hx" <<'HAXE'
package data;

class Song
{
}
HAXE

# Only what the ported files read from PlayState. The real one is far too large to
# pull in here, and every member below is used by Popup/TimingPopup/JudgeText.
cat > "$test_source/play/PlayState.hx" <<'HAXE'
package play;

import backend.ClientPrefs;
import backend.Conductor.Rating;
import flixel.FlxSprite;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import flixel.sound.FlxSound;
import flixel.text.FlxText;
import flixel.tweens.FlxTween;
import objects.Boyfriend;
import objects.Popup;
import objects.TimingPopup;
import play.helpers.HitTiming;
import play.objects.JudgeText;
import play.objects.MSText;
import play.objects.MissCounter;

/**
 * The slice of PlayState that `PlayStateRating` touches, with the declarations
 * copied from the real `source/play/PlayState.hx` (same names, types, defaults
 * and visibility) so the helper is compiled against its real contract instead of
 * a hand-trimmed one. Refresh it when PlayState gains a member the helper uses.
 */
class PlayState
{
  public static var instance:PlayState;
  public var adaptiveRatingsDisabled:Bool = false;
	public static var campaignMisses:Int = 0;
	public static var changedDifficulty:Bool = false;
	public static var chartingMode:Bool = false;
	public static var isStoryMode:Bool = false;
	public static var opponentChart:Bool = false;
	public static var isPixelStage:Bool = false;
	public static var daPixelZoom:Float = 6;
	public static var ratingStuff:Array<Array<Dynamic>> = [[0.5, 'Bad']];
	public static var storyPlaylist:Array<String> = [];

	public var accuracy:String;

	public var bads:Int = 0;

	public var botText:String;

	public var boyfriend:Boyfriend = null;

	public var boyfriendIdled:Bool = false;

	public function callOnLuas(event:String, args:Array<Dynamic> = null, ignoreStops = true, exclusions:Array<String> = null, excludeValues:Array<Dynamic> = null):Dynamic
  {
    return null;
  }

	public var combo:Float = 0;

	public var comboInfo = ClientPrefs.showComboInfo;

	public var cpuControlled:Bool = false;

	public var daRating:Rating = null;

	public function doDeathCheck(?skipHealthCheck:Bool = false)
  {
  }

	public var fcString:String;

	public var fcStrings:Array<String> = ['No Play', 'PFC', 'SFC', 'GFC', 'BFC', 'FC', 'SDCB', 'Clear', 'TDCB', 'QDCB'];

	public var ffmpegMode = ClientPrefs.ffmpegMode;

	public var formattedCombo:String;

	public var formattedMaxNPS:String;

	public var formattedNPS:String;

	public var formattedScore:String;

	public var formattedSongMisses:String;

	public var goods:Int = 0;

	public inline function hasActiveScripts():Bool
  {
    return false;
  }

	public var hitStrings:Array<String> = ['Perfect!!!', 'Sick!!', 'Good!', 'Bad.', 'Poor.', 'Miss..'];

	public var hitTiming:String = HitTiming.NONE;

	public var botplayTxt:FlxText;


	public var instakillOnMiss:Bool = false;

	public var judgeTxt:JudgeText;

	public var keysPressed:Array<Bool> = [];

	public var maxNPS:Float = 0;

	public var maxOppNPS:Float = 0;

	public var missCounter:MissCounter = new MissCounter();

	public var missRecalcsPerFrame:Int = 0;

	public var missString:String = '';

	public var msTxt:MSText;

	public var noteDiff = 0.0;

	public var noteTimingDiff:Float = 0.0;

	public var notesHitArray:Array<Float> = [];

	public var notesHitDateArray:Array<Float> = [];

	public var notesToRemoveCount:Int = 0;

	public var nps:Float = 0;

	public var npsSpeedMult:Float = 1;

	public var npsString:String;

	public var numScore:Popup = null;

	public var oppNPS:Float = 0;

	public var oppNotesHitArray:Array<Float> = [];

	public var oppNotesHitDateArray:Array<Float> = [];

	public var oppNotesToRemoveCount:Int = 0;

	public var opponentVocals:FlxSound;

	public var perfects:Int = 0;

	public var pixelRatingPrefix:String = "";

	public var pixelRatingSuffix:String = '';

	public var playbackRate:Float = 1;

	public var polyphonyBF:Float = 1;

	public var polyphonyOppo:Float = 1;

	public var poorRatings:Int = 0;

	public var popUpGroup:FlxTypedSpriteGroup<Popup>;

	public var popUpsFrame:Int = 0;

	public var practiceMode:Bool = false;

	public var rating:Popup = null;

	public var ratingFC:String;

	public var ratingName:String = '?';

	public var ratingPercent:Float;

	public var ratingString:String;

	public var ratingsData:Array<Rating> = Rating.loadDefault();

	public var scoreTxt:FlxText;

	public var scoreTxtTween:FlxTween;

	public var scoreTxtUpdateFrame:Int = 0;

	public var separatedScore:Array<Dynamic> = [];

	public function setOnLuas(variable:String, arg:Dynamic)
  {
  }

	public var showComboNum:Bool = true;

	public var showNPS = ClientPrefs.showNPS;

	public var showRating:Bool = true;

	public var shownScore:Float = 0;

	public var sickOnly:Bool = false;

	public var sicks:Int = 0;

	public var songHits:Int = 0;

	public var songMisses:Float = 0;

	public var songName:String;

	public var songScore:Float = 0;

	public var splashesPerFrame:Array<Int> = [0, 0, 0, 0];

	public var tempScore:String;

	public var timingAssets:Map<String, Null<String>> = [];

	public var timingGroup:FlxTypedSpriteGroup<TimingPopup>;

	public var timingPopup:TimingPopup = null;

	public var totalNotesHit:Float = 0.0;

	public var totalPlayed:Int = 0;

	public var trollingMode:Bool = false;

	public dynamic function updateScore(miss:Bool = false)
  {
  }

	public var vocals:FlxSound;

  public function new() {}

  public static function formatNumber(value:Float):String return Std.string(value);
}
HAXE

cat > "$test_source/objects/Boyfriend.hx" <<'HAXE'
package objects;

class Boyfriend extends flixel.FlxSprite
{
  public var holdTimer:Float = 0;
}
HAXE

cat > "$test_source/play/objects/MSText.hx" <<'HAXE'
package play.objects;

class MSText extends flixel.text.FlxText
{
  public function new(?camHUD:flixel.FlxCamera) super();
}
HAXE

cat > "$test_source/backend/Achievements.hx" <<'HAXE'
package backend;

class Achievements
{
  public static function exists(name:String):Bool return false;
  public static function unlock(name:String):Void {}
}
HAXE

cat > "$test_source/backend/Highscore.hx" <<'HAXE'
package backend;

class Highscore
{
  public static function floorDecimal(value:Float, decimals:Int):Float return value;
}
HAXE

cat > "$test_source/backend/CoolUtil.hx" <<'HAXE'
package backend;

class CoolUtil
{
  public static function coolTextFile(path:String):Array<String> return [];
}
HAXE

cat > "$test_source/backend/WeekData.hx" <<'HAXE'
package backend;

class WeekData
{
  public static function getWeekFileName():String return 'week1';
}
HAXE

cat > "$test_source/backend/Mods.hx" <<'HAXE'
package backend;

class Mods
{
  public static function mergeAllTextsNamed(path:String, ?defaultDirectory:String, allowDuplicates:Bool = false):Array<String> return [];
}
HAXE

cat > "$test_source/psychlua/EtternaFunctions.hx" <<'HAXE'
package psychlua;

class EtternaFunctions
{
  public static function wife3(maxms:Float, ts:Float):Float return 1;
}
HAXE

cat > "$test_source/play/helpers/PlayStateNoteHelpers.hx" <<'HAXE'
package play.helpers;

import objects.Note;
import play.PlayState;

class PlayStateNoteHelpers
{
  public static function spawnNoteSplashOnNote(state:PlayState, isDad:Bool, note:Note):Void {}
}
HAXE

cat > "$test_source/play/helpers/PlayStatePlayback.hx" <<'HAXE'
package play.helpers;

import play.PlayState;

class PlayStatePlayback
{
  public static function vocalsVolume(state:PlayState):Float return 1;
}
HAXE

# ---- drives the public surface the port adds -------------------------------

cat > "$test_source/TypecheckMain.hx" <<'HAXE'
import backend.Conductor;
import flixel.group.FlxSpriteGroup.FlxTypedSpriteGroup;
import objects.Popup;
import objects.TimingPopup;
import play.PlayState;
import play.helpers.HitTiming;

class TypecheckMain
{
  static function main():Void
  {
    final state = new PlayState();
    PlayState.instance = state;
    state.popUpGroup = new FlxTypedSpriteGroup<Popup>();
    state.timingGroup = new FlxTypedSpriteGroup<TimingPopup>();

    // The classification the rating helper feeds the label.
    final timing:String = HitTiming.classify(60, Conductor.safeZoneOffset, 0.1);
    state.combo = 12;
    trace('timing=$timing label="${HitTiming.label(timing)}"');

    final rating:Popup = state.popUpGroup.recycle(Popup);
    rating.setupRating('ratings/default/sick');

    // Pooled label: recycle, load, place under the rating, fade, kill.
    final label:TimingPopup = state.timingGroup.recycle(TimingPopup);
    trace('label art loaded: ' + label.setup('ratings/default/early'));
    trace('missing art loaded: ' + label.setup('ratings/default/nope'));
    label.setup('ratings/default/early');
    label.place(rating, 0, 0);
    label.alphaTween();
    trace('label popTime=' + label.popTime + ' scale=' + TimingPopup.scaleFactor());
    label.kill();

    // Rating popup still behaves, and a recycled digit clears the label slot.
    rating.setupNumber('ratings/default/num1', 0, 1);
    rating.alphaTween();
    rating.kill();
    trace('popups: ' + state.popUpGroup.length + ' labels: ' + state.timingGroup.length);
  }
}
HAXE

common="-cp $test_source -cp $flixel -cp $openfl -cp $lime -D lime=8.1.2 -D openfl=9.3.0"
# Last -cp wins for duplicate definitions, so the shim goes after the real lime.
if [ -n "$lime_shim" ]; then
  common="$common -cp $lime_shim"
fi
if [ -n "$addons" ]; then
  common="$common -cp $addons"
fi

echo "Typechecking the Early/Late popups for native..."
# shellcheck disable=SC2086
"${HAXE:-haxe}" $common -D windows -D desktop -D native -D lime_native -D lime_opengl \
  -main TypecheckMain -cpp "$test_source/cpp" --no-output

echo "EarlyLate typecheck: PASS"
