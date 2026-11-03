#!/usr/bin/env bash
# Isolate backend/MemoryLedger.hx from source/import.hx's Flixel/OpenFL imports
# and exercise the per-area RAM accounting with tiny dependency stubs. Runs the
# contract spec in the Haxe interpreter (no native toolchain needed) and then
# typechecks the native cpp path, where cpp.vm.Gc.memInfo64 is used.
set -euo pipefail
cd "$(dirname "$0")/../.."
test_source=$(mktemp -d)
trap 'rm -rf "$test_source"' EXIT
mkdir -p "$test_source/backend" "$test_source/utils" \
  "$test_source/openfl/display" "$test_source/openfl/media" \
  "$test_source/lime/media" "$test_source/lime/utils"

# Production modules under test.
cp source/backend/MemoryLedger.hx "$test_source/backend/"
cp source/utils/MemoryUtil.hx "$test_source/utils/"

# --- Stubs ------------------------------------------------------------------
cat > "$test_source/backend/VLog.hx" <<'HAXE'
package backend;
class VLog
{
  public static var fakeHeap:Float = 1000000;
  public static function heapUsedBytes():Float return fakeHeap;
}
HAXE
cat > "$test_source/backend/Mods.hx" <<'HAXE'
package backend;
class Mods
{
  public static var ignoreModFolders:Array<String> =
    ['images', 'data', 'songs', 'sounds', 'fonts', 'videos', 'weeks', 'scripts', 'stages', 'characters'];
}
HAXE
cat > "$test_source/openfl/display/BitmapData.hx" <<'HAXE'
package openfl.display;
class BitmapData
{
  public var width:Int;
  public var height:Int;
  public function new(width:Int, height:Int)
  {
    this.width = width;
    this.height = height;
  }
}
HAXE
cat > "$test_source/lime/utils/UInt8Array.hx" <<'HAXE'
package lime.utils;
class UInt8Array
{
  public var length:Int;
  public function new(length:Int) this.length = length;
}
HAXE
cat > "$test_source/lime/media/AudioBuffer.hx" <<'HAXE'
package lime.media;
class AudioBuffer
{
  public var data:lime.utils.UInt8Array;
  public function new() {}
}
HAXE
cat > "$test_source/openfl/media/Sound.hx" <<'HAXE'
package openfl.media;
class Sound
{
  public var bytesTotal:Int = 0;
  public var __buffer:lime.media.AudioBuffer;
  public function new() {}
}
HAXE

# --- Behavioral run in the interpreter (also typechecks the whole module) ----
"${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main MemoryLedgerSpec --interp -D MODS_ALLOWED

# --- Typecheck the native cpp path (cpp.vm.Gc.memInfo64 reserved heap) --------
mkdir -p "$test_source/cpp/vm"
cat > "$test_source/cpp/vm/Gc.hx" <<'HAXE'
package cpp.vm;
class Gc
{
  public static inline var MEM_INFO_USAGE:Int = 0;
  public static inline var MEM_INFO_RESERVED:Int = 1;
  public static function memInfo64(kind:Int):Float return 0;
}
HAXE
for platform in windows android; do
  "${HAXE:-haxe}" -cp "$test_source" -cp tests/haxe -main MemoryLedgerSpec \
    -D MODS_ALLOWED -D "$platform" -cpp "$test_source/out-$platform" --no-output
done
