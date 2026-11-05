# Port of run-pool-stats.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-pool-stats-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/debug" -Force | Out-Null
    Copy-Item "source/debug/PoolStats.hx" "$testSource/debug/PoolStats.hx"
    & $haxe -cp $testSource -cp tests/haxe -main PoolStatsSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
