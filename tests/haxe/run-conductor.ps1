# Port of run-conductor.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-conductor-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$work/backend", "$work/data", "$work/objects", "$work/play" -Force | Out-Null
try {
    Copy-Item "source/backend/Conductor.hx" "$work/backend/Conductor.hx"
    Copy-Item "tests/haxe/stubs/backend/ClientPrefs.hx" "$work/backend/ClientPrefs.hx"
    Copy-Item "tests/haxe/stubs/data/Song.hx" "$work/data/Song.hx"
    Copy-Item "tests/haxe/stubs/data/Section.hx" "$work/data/Section.hx"
    Copy-Item "tests/haxe/stubs/objects/Note.hx" "$work/objects/Note.hx"
    Copy-Item "tests/haxe/stubs/objects/NoteSplash.hx" "$work/objects/NoteSplash.hx"
    Copy-Item "tests/haxe/stubs/play/PlayState.hx" "$work/play/PlayState.hx"
    & $haxe -cp $work -cp "$repo/tests/haxe" -main ConductorSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ConductorSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
