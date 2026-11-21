#!/usr/bin/env bash
# First-run performance preset selection; no game haxelibs required.
set -euo pipefail
root="$(cd "$(dirname "$0")/../.." && pwd)"
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
mkdir -p "$work/backend" "$work/debug/system" "$work/flixel"
cp "$root/source/backend/FirstRunPerformance.hx" "$work/backend/FirstRunPerformance.hx"
cat > "$work/backend/ClientPrefs.hx" <<'HX'
package backend;
class ClientPrefs {
  public static var firstRunPerformanceVersion:Int = 0;
  public static var framerate:Int = 60;
  public static var lowQuality:Bool = false;
  public static var shaders:Bool = true;
  public static var cacheOnGPU:Bool = false;
  public static var dynamicSpawnTime:Bool = false;
  public static var enableGC:Bool = true;
  public static var noRenderGC:Bool = false;
  public static var maxSplashLimit:Int = 16;
  public static function saveSettings():Void {}
}
HX
cat > "$work/backend/FramerateController.hx" <<'HX'
package backend;
class FramerateController { public static function apply(value:Int):Void {} }
HX
cat > "$work/backend/Native.hx" <<'HX'
package backend;
typedef HardwareInfo = { var gpuModel:String; }
class Native {
  public static inline var UNKNOWN:String = 'Unknown';
  public static function getSystemInfo():HardwareInfo return {gpuModel: 'Unknown'};
  public static function getGPUEnhancements():String return 'Unknown GPU';
}
HX
cat > "$work/debug/system/SystemInfo.hx" <<'HX'
package debug.system;
class SystemInfo {
  public static function totalPhysicalMemory():Float return 0;
  public static function logicalCPUCount():Int return 0;
}
HX
cat > "$work/flixel/FlxG.hx" <<'HX'
package flixel;
class FlxG { public static var save:Dynamic; }
HX
"${HAXE:-haxe}" -cp "$work" -cp "$root/tests/haxe" -main FirstRunPerformanceSpec --interp
