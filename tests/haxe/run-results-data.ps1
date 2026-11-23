# Port of run-results-data.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-results-data-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$work/states", "$work/backend", "$work/play" -Force | Out-Null
try {
    Copy-Item "source/states/ResultsData.hx" "$work/states/ResultsData.hx"
    Copy-Item "tests/haxe/stubs/results-data/backend/CoolUtil.hx" "$work/backend/CoolUtil.hx"
    Copy-Item "tests/haxe/stubs/results-data/play/PlayState.hx" "$work/play/PlayState.hx"
    & $haxe -cp $work -cp "$repo/tests/haxe" -main ResultsDataSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ResultsDataSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
