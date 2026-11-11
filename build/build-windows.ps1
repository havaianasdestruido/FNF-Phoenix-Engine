# Phoenix Engine - Windows release build. Port of build-windows.bat; keep the
# two variants in sync.
#
# Modding level 2 (Lua + Python) is the default for every native target in
# project.hxp, so -DMODDING_LEVEL is not needed: a plain `lime build windows`
# already includes both script languages. Extra arguments are passed straight
# through to Lime, e.g. `./build-windows.ps1 -DMODDING_LEVEL=1`.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    Write-Host '[Phoenix Engine] Building Windows (Release)...'
    & haxelib run lime build windows -release @args
    if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
    Write-Host '[Phoenix Engine] Done. Output: build\release\windows\bin'
} finally {
    Pop-Location
}
