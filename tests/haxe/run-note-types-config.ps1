# Port of run-note-types-config.sh - keep in sync with the .sh / .bat versions.
# The spec runs with the fixture tree as the working directory.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-note-types-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$work/backend", "$work/objects", "$work/custom_notetypes" -Force | Out-Null
try {
    Copy-Item "source/backend/NoteTypesConfig.hx" "$work/backend/NoteTypesConfig.hx"
    Copy-Item "tests/haxe/stubs/note-types/import.hx" "$work/import.hx"
    Copy-Item "tests/haxe/stubs/note-types/backend/CoolUtil.hx" "$work/backend/CoolUtil.hx"
    Copy-Item "tests/haxe/stubs/note-types/backend/Paths.hx" "$work/backend/Paths.hx"
    Copy-Item "tests/haxe/stubs/note-types/objects/Note.hx" "$work/objects/Note.hx"
    Copy-Item "tests/haxe/fixtures/note-types/custom_notetypes/*.txt" "$work/custom_notetypes/"
    Push-Location $work
    try {
        & $haxe -cp $work -cp "$repo/tests/haxe" -main NoteTypesConfigSpec --interp
        if ($LASTEXITCODE -ne 0) { throw "NoteTypesConfigSpec failed ($LASTEXITCODE)" }
    } finally { Pop-Location }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
