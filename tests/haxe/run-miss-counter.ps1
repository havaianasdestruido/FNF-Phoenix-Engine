# Port of run-miss-counter.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-miss-counter-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/play/objects" -Force | Out-Null
    Copy-Item "source/play/objects/MissCounter.hx" "$testSource/play/objects/MissCounter.hx"
    & $haxe -cp $testSource -cp tests/haxe -main MissCounterSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "MissCounterSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
