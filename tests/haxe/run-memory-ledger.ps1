# Port of run-memory-ledger.sh - keep in sync with the .sh / .bat versions.
# Isolate backend/MemoryLedger.hx and exercise the per-area RAM accounting.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-memory-ledger-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null

function Invoke-Haxe {
    param([string[]]$HaxeArgs)
    & $haxe @HaxeArgs
    if ($LASTEXITCODE -ne 0) { throw "haxe failed ($LASTEXITCODE): $HaxeArgs" }
}

try {
    foreach ($dir in @("backend", "utils", "openfl/display", "openfl/media", "lime/media", "lime/utils")) {
        New-Item -ItemType Directory -Path "$testSource/$dir" -Force | Out-Null
    }
    Copy-Item "source/backend/MemoryLedger.hx" "$testSource/backend/"
    Copy-Item "source/utils/MemoryUtil.hx" "$testSource/utils/"

    Set-Content -LiteralPath "$testSource/backend/VLog.hx" -Value @'
package backend;
class VLog
{
  public static var fakeHeap:Float = 1000000;
  public static function heapUsedBytes():Float return fakeHeap;
}
'@
    Set-Content -LiteralPath "$testSource/backend/Mods.hx" -Value @'
package backend;
class Mods
{
  public static var ignoreModFolders:Array<String> =
    ['images', 'data', 'songs', 'sounds', 'fonts', 'videos', 'weeks', 'scripts', 'stages', 'characters'];
}
'@
    Set-Content -LiteralPath "$testSource/openfl/display/BitmapData.hx" -Value @'
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
'@
    Set-Content -LiteralPath "$testSource/lime/utils/UInt8Array.hx" -Value @'
package lime.utils;
class UInt8Array
{
  public var length:Int;
  public function new(length:Int) this.length = length;
}
'@
    Set-Content -LiteralPath "$testSource/lime/media/AudioBuffer.hx" -Value @'
package lime.media;
class AudioBuffer
{
  public var data:lime.utils.UInt8Array;
  public function new() {}
}
'@
    Set-Content -LiteralPath "$testSource/openfl/media/Sound.hx" -Value @'
package openfl.media;
class Sound
{
  public var bytesTotal:Int = 0;
  public var __buffer:lime.media.AudioBuffer;
  public function new() {}
}
'@

    Invoke-Haxe @("-cp", $testSource, "-cp", "tests/haxe", "-main", "MemoryLedgerSpec", "--interp", "-D", "MODS_ALLOWED")

    New-Item -ItemType Directory -Path "$testSource/cpp/vm" -Force | Out-Null
    Set-Content -LiteralPath "$testSource/cpp/vm/Gc.hx" -Value @'
package cpp.vm;
class Gc
{
  public static inline var MEM_INFO_USAGE:Int = 0;
  public static inline var MEM_INFO_RESERVED:Int = 1;
  public static function memInfo64(kind:Int):Float return 0;
}
'@
    foreach ($platform in @("windows", "android")) {
        Invoke-Haxe @("-cp", $testSource, "-cp", "tests/haxe", "-main", "MemoryLedgerSpec",
            "-D", "MODS_ALLOWED", "-D", $platform, "-cpp", "$testSource/out-$platform", "--no-output")
    }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
