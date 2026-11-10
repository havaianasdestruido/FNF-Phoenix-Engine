# Port of run-hit-timing.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-hit-timing-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/play/helpers" -Force | Out-Null
    Copy-Item "source/play/helpers/HitTiming.hx" "$testSource/play/helpers/HitTiming.hx"
    & $haxe -cp $testSource -cp tests/haxe -main HitTimingSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "HitTimingSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
