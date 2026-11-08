# Port of run-distant-notes.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-distant-notes-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    Copy-Item -Recurse -Force "tests/haxe/stubs/distant-notes/*" $testSource
    New-Item -ItemType Directory -Path "$testSource/play/helpers" -Force | Out-Null
    Copy-Item "source/play/helpers/PlayStateDistantNotes.hx" "$testSource/play/helpers/PlayStateDistantNotes.hx"
    & $haxe -cp $testSource -cp tests/haxe -D SHADERS_ALLOWED -main DistantNotesSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "DistantNotesSpec failed ($LASTEXITCODE)" }
    & $haxe -cp $testSource -cp tests/haxe -main DistantNotesFallbackSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "DistantNotesFallbackSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
