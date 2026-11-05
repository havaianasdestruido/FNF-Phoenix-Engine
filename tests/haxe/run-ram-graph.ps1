# Port of run-ram-graph.sh - keep in sync with the .sh / .bat versions.
# Run the graph's data/geometry tests without the game's OpenFL dependencies.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-ram-graph-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/debug" -Force | Out-Null
    Copy-Item "source/debug/RamGraphHistory.hx" "$testSource/debug/"
    & $haxe -cp $testSource -cp tests/haxe -main RamGraphHistorySpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
