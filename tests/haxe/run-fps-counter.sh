#!/usr/bin/env bash
# Exercise the real FPSCounter with small OpenFL/Flixel stand-ins.
set -euo pipefail
root=$(cd "$(dirname "$0")/../.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp"/{debug/mem,backend,play,states,lime/system,openfl/events,openfl/text}
cp "$root/source/debug/FPSCounter.hx" "$tmp/debug/"
cat > "$tmp/import.hx" <<'HAXE'
import FlxG;
import FlxColor;
import MemoryUtil;
HAXE
cat > "$tmp/backend/ClientPrefs.hx" <<'HAXE'
package backend;
class ClientPrefs {
  public static var showFPS = true;
  public static var showRamUsage = true;
  public static var showMaxRamUsage = true;
  public static var legacyFPSUI = false;
  public static var frameProfiler = false;
  public static var debugInfo = false;
  public static var ffmpegMode = false;
  public static var targetFPS = 60;
  public static var framerate = 60;
  public static var rainbowFPS = false;
}
HAXE
cat > "$tmp/FlxG.hx" <<'HAXE'
class FlxG {
  public static var state:FakeState = new FakeState();
  public static var drawFramerate = 60;
  public static var signals = {gameResized: new ResizeSignal()};
}
class FakeState {
  public var subState:FakeState = null;
  public function new() {}
}
class ResizeSignal {
  public function new() {}
  public function add(f:Int->Int->Void):Void {}
}
HAXE
cat > "$tmp/FlxColor.hx" <<'HAXE'
class FlxColor { public static function fromHSB(h:Float, s:Float, b:Float):Int return 0; }
HAXE
cat > "$tmp/Main.hx" <<'HAXE'
class Main { public static function getTime():Float return 0; }
HAXE
cat > "$tmp/MemoryUtil.hx" <<'HAXE'
class MemoryUtil { public static function formatMemory(bytes:Float):String return Std.int(bytes) + ' B'; }
HAXE
cat > "$tmp/play/PlayState.hx" <<'HAXE'
package play;
class PlayState extends FakeState {
  public static var instance:PlayState;
  public var trollingMode = false;
  public var playbackRate:Float = 1;
}
HAXE
cat > "$tmp/states/MainMenuState.hx" <<'HAXE'
package states;
class MainMenuState {
  public static var phoenixEngineVersion = '1';
  public static var psychEngineJSVersion = '1';
}
HAXE
cat > "$tmp/debug/FrameProfiler.hx" <<'HAXE'
package debug;
class FrameProfiler { public static function getOverlayText():String return 'Profiler'; }
HAXE
cat > "$tmp/debug/PoolStats.hx" <<'HAXE'
package debug;
class PoolStats {
  public static function totalSpawned():Int return 1;
  public static function summary():String return 'pool stats';
}
HAXE
cat > "$tmp/debug/mem/GetTotalMemory.hx" <<'HAXE'
package debug.mem;
class GetTotalMemory {
  public static function getCurrentRSS():Float return 123;
  public static function getPeakRSS():Float return 456;
}
HAXE
cat > "$tmp/lime/system/System.hx" <<'HAXE'
package lime.system;
class System {
  public static var platformName = 'Test';
  public static var platformVersion = 'Test';
}
HAXE
cat > "$tmp/openfl/events/Event.hx" <<'HAXE'
package openfl.events;
class Event {
  public static inline var ADDED_TO_STAGE = 'added';
  public static inline var ENTER_FRAME = 'enter';
}
HAXE
cat > "$tmp/openfl/text/TextFormatAlign.hx" <<'HAXE'
package openfl.text;
enum abstract TextFormatAlign(String) { var LEFT = 'left'; var CENTER = 'center'; var RIGHT = 'right'; }
HAXE
cat > "$tmp/openfl/text/TextFormat.hx" <<'HAXE'
package openfl.text;
class TextFormat {
  public var align:TextFormatAlign;
  public function new(font:String, size:Int, color:Int) {}
}
HAXE
cat > "$tmp/openfl/text/TextField.hx" <<'HAXE'
package openfl.text;
import openfl.events.Event;
enum abstract TextFieldAutoSize(String) { var LEFT = 'left'; var CENTER = 'center'; var RIGHT = 'right'; }
class TextField {
  public var x:Float;
  public var y:Float;
  public var selectable:Bool;
  public var mouseEnabled:Bool;
  public var defaultTextFormat:TextFormat;
  public var autoSize:TextFieldAutoSize;
  public var multiline:Bool;
  public var text:String;
  public var textColor:Int = 0;
  public var textWidth:Float = 0;
  public var stage = {stageWidth: 1280};
  public function new() {}
  public function addEventListener(name:String, f:Event->Void):Void {}
}
HAXE
haxe -cp "$tmp" -cp "$root/tests/haxe" -main FPSCounterSpec --interp
