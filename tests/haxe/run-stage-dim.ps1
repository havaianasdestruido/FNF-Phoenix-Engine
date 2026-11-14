# Port of run-stage-dim.sh - keep in sync with the .sh version.
# Only the spec runs here; the options-row guards in the .sh are bash greps and
# the .sh is what CI calls.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-stage-dim-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    Copy-Item "tests/haxe/stubs/stage-dim/*" $testSource -Recurse -Force
    New-Item -ItemType Directory -Path "$testSource/play/helpers" -Force | Out-Null
    Copy-Item "source/play/helpers/StageDimMath.hx" "$testSource/play/helpers/StageDimMath.hx"
    Copy-Item "source/play/helpers/PlayStateStageDim.hx" "$testSource/play/helpers/PlayStateStageDim.hx"
    & $haxe -cp $testSource -cp tests/haxe -main StageDimSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "StageDimSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
