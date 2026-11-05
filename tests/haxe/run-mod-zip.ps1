# Port of run-mod-zip.sh - keep in sync with the .sh / .bat versions.
# Isolate the dependency-free pieces of the `.zip` mod importer; the spec
# creates and deletes relative scratch directories, so run it in the work dir.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-mod-zip-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$work/backend", "$work/mobile/files" -Force | Out-Null
    Copy-Item "source/backend/ModPathPolicy.hx" "$work/backend/ModPathPolicy.hx"
    Copy-Item "source/mobile/files/ModZipInstaller.hx" "$work/mobile/files/ModZipInstaller.hx"
    Push-Location $work
    try {
        & $haxe -cp $work -cp "$repo/tests/haxe" -main ModZipImportSpec --interp
        if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
    } finally { Pop-Location }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
