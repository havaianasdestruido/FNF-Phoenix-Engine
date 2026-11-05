# Port of run-alphabet-font.sh - keep in sync with the .sh / .bat versions.
# Isolate the alphabet font model from source/import.hx's Flixel/OpenFL imports;
# these tests run without game haxelibs.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-alphabet-font-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/objects", "$testSource/backend" -Force | Out-Null
    Copy-Item "source/objects/AlphabetFont.hx" "$testSource/objects/AlphabetFont.hx"
    Copy-Item "tests/haxe/stubs/backend/ClientPrefs.hx" "$testSource/backend/ClientPrefs.hx"
    & $haxe -cp $testSource -cp tests/haxe -main AlphabetFontSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "AlphabetFontSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
