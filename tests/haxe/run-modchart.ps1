# Port of run-modchart.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-modchart-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/modchart" -Force | Out-Null
    Copy-Item "source/modchart/*" "$testSource/modchart/" -Recurse -Force
    & $haxe -cp $testSource -cp tests/haxe -main ModchartSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ModchartSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
