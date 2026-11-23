# Port of run-hotspot-profiler.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-hotspot-profiler-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$work/debug/profiler" -Force | Out-Null
try {
    Copy-Item "source/debug/profiler/HotspotProfiler.hx" "$work/debug/profiler/HotspotProfiler.hx"
    Copy-Item "tests/haxe/stubs/hotspot-profiler/debug/FrameProfiler.hx" "$work/debug/FrameProfiler.hx"
    & $haxe -cp $work -cp "$repo/tests/haxe" -main HotspotProfilerSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "HotspotProfilerSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
