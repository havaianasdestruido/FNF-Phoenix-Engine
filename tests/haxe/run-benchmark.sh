#!/usr/bin/env bash
# Compile and run the Device Benchmark spec in the Haxe interpreter, against
# stubbed game types and the import-free chart modules — no game haxelibs needed:
#
#   backend/BenchmarkChart.hx     the fixed 60 s charts: gameplay, visual, logic;
#   backend/BenchmarkKind.hx      enum of benchmark kinds;
#   backend/BenchmarkKindTools.hx display helpers for the kinds;
#   backend/BenchmarkSynthetic.hx synthetic micro-benchmarks;
#   backend/RecoveryBoot.hx       the shared `modsDisabled()` predicate the mod
#                                 lookups consult, flipped by Safe Mode or by
#                                 the benchmark flag (the real `backend.Benchmark`
#                                 controller pulls in PlayState and Flixel, so the
#                                 stub only provides its static `active` flag);
#   the rest of the wiring (options rows, PlayState hooks, endSong branch,
#   Paths/Mods predicate, pause menu, bundle assets, suite) is pinned by
#   scanning the repo sources, which is why this runs from the repository root.
set -euo pipefail
cd "$(dirname \"$0\")/../.."
root=$(pwd)
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/lime/system" "$test_source/debug/system"
cp source/backend/BenchmarkChart.hx "$test_source/backend/BenchmarkChart.hx"
cp source/backend/BenchmarkKind.hx "$test_source/backend/BenchmarkKind.hx"
cp source/backend/BenchmarkKindTools.hx "$test_source/backend/BenchmarkKindTools.hx"
cp source/backend/BenchmarkSynthetic.hx "$test_source/backend/BenchmarkSynthetic.hx"
cp source/backend/RecoveryBoot.hx "$test_source/backend/RecoveryBoot.hx"
cat > "$test_source/lime/system/System.hx" <<'EOF'
package lime.system;
/** Test stub: RecoveryBoot only reads the application storage directory. */
class System
{
  public static var applicationStorageDirectory:String = '/tmp/';
}
EOF
cat > "$test_source/debug/system/SystemInfo.hx" <<'EOF'
package debug.system;
class SystemInfo
{
  public static inline function logicalCPUCount():Int return 1;
  public static inline function totalPhysicalMemory():Float return 0;
}
EOF
cat > "$test_source/backend/Benchmark.hx" <<'EOF'
package backend;
/** Test stub: only the flag the mod-suppression predicate reads. */
class Benchmark
{
  public static var active:Bool = false;
  public static var kind:Null<BenchmarkKind> = null;
  public static function start():Void {}
  public static function startKind(?k:BenchmarkKind):Void {}
  public static function startVisual():Void {}
  public static function startLogic():Void {}
  public static function startSynthetic():Void {}
  public static function startSuite():Void {}
}
EOF
cat > "$test_source/backend/Native.hx" <<'EOF'
package backend;
typedef HardwareInfo = { osName:String, osVersion:String, gpuModel:String, gpuVendor:String, gpuDriver:String, graphicsApi:String, audioApi:String, cpuModel:String, cpuVendor:String };
class Native
{
  public static inline var UNKNOWN:String = "Unknown";
  public static function getSystemInfo():HardwareInfo
    return { osName: "TestOS", osVersion: "1", gpuModel: "TestGPU", gpuVendor: "TestVendor", gpuDriver: "1.0", graphicsApi: "TestGL", audioApi: "TestAudio", cpuModel: "TestCPU", cpuVendor: "TestVendor" };
}
EOF
cat > "$test_source/backend/PhoenixVersion.hx" <<'EOF'
package backend;
class PhoenixVersion
{
  public static inline var current:String = "0.0.0-test";
  public static inline var FALLBACK:String = "0.0.0";
}
EOF
cat > "$test_source/backend/ClientPrefs.hx" <<'EOF'
package backend;
class ClientPrefs { public static var framerate:Int = 60; }
EOF
cat > "$test_source/debug/FrameProfiler.hx" <<'EOF'
package debug;
class FrameProfiler
{
  public static function getSummary():Dynamic return null;
  public static function reset():Void {}
  public static function exportLog(?name:String):String return "";
}
EOF
cat > "$test_source/flixel/FlxG.hx" <<'EOF'
package flixel;
class FlxG { public static var width:Int = 1280; public static var height:Int = 720; }
EOF
"${HAXE:-haxe}" -cp "$test_source" -cp "$root/tests/haxe" -main BenchmarkSpec --interp
