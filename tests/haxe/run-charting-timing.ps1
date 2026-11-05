# Port of run-charting-timing.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-charting-timing-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    foreach ($dir in @("editors/charting", "backend", "data", "objects", "play")) {
        New-Item -ItemType Directory -Path "$testSource/$dir" -Force | Out-Null
    }
    Copy-Item "source/editors/charting/ChartingTiming.hx" "$testSource/editors/charting/ChartingTiming.hx"
    Copy-Item "source/backend/Conductor.hx" "$testSource/backend/Conductor.hx"
    Copy-Item "tests/haxe/stubs/backend/ClientPrefs.hx" "$testSource/backend/ClientPrefs.hx"
    Copy-Item "tests/haxe/stubs/data/Section.hx" "$testSource/data/Section.hx"
    Copy-Item "tests/haxe/stubs/data/Song.hx" "$testSource/data/Song.hx"
    Copy-Item "tests/haxe/stubs/objects/Note.hx" "$testSource/objects/Note.hx"
    Copy-Item "tests/haxe/stubs/objects/NoteSplash.hx" "$testSource/objects/NoteSplash.hx"
    Copy-Item "tests/haxe/stubs/play/PlayState.hx" "$testSource/play/PlayState.hx"
    & $haxe -cp $testSource -cp tests/haxe -main ChartingTimingSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
