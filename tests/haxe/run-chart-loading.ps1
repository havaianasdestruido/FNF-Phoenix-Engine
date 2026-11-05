# Port of run-chart-loading.sh - keep in sync with the .sh / .bat versions.
# Exercise the production data/Song.hx JSON normalizer without the game haxelibs.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-chart-loading-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    Copy-Item -Recurse -Force "tests/haxe/stubs/chart-loading/*" $testSource
    New-Item -ItemType Directory -Path "$testSource/data" -Force | Out-Null
    Copy-Item "source/data/Song.hx" "$testSource/data/Song.hx"
    & $haxe -cp $testSource -cp tests/haxe -main ChartLoadingSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
    & $haxe -cp $testSource -cp tests/haxe -main ChartLoadingSpec -js "$testSource/chart-loading.js"
    if ($LASTEXITCODE -ne 0) { throw "haxe js failed ($LASTEXITCODE)" }
    node "$testSource/chart-loading.js"
    if ($LASTEXITCODE -ne 0) { throw "node failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
