# Port of run-chart-loader.sh - keep in sync with the .sh / .bat versions.
# Exercise the production gameplay chart loader with renderer-free stubs.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-chart-loader-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    Copy-Item -Recurse -Force "tests/haxe/stubs/chart-loader/*" $testSource
    New-Item -ItemType Directory -Path "$testSource/play/helpers" -Force | Out-Null
    Copy-Item "source/play/helpers/PlayStateChartLoader.hx" "$testSource/play/helpers/PlayStateChartLoader.hx"
    & $haxe -cp $testSource -cp tests/haxe -main ChartLoaderSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
    & $haxe -cp $testSource -cp tests/haxe -main ChartLoaderSpec -js "$testSource/chart-loader.js"
    if ($LASTEXITCODE -ne 0) { throw "haxe js failed ($LASTEXITCODE)" }
    node "$testSource/chart-loader.js"
    if ($LASTEXITCODE -ne 0) { throw "node failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
