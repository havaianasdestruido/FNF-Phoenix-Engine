# Phoenix Engine - iOS release build. Port of build-ios.sh; keep both in sync.
# Modding level 2 is the default, iOS included. Extra arguments are passed
# through to Lime.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    Write-Host '[Phoenix Engine] Building iOS (Release)...'
    & haxelib run lime build ios -release @args
    if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
    Write-Host '[Phoenix Engine] Done. Xcode project: build/release/ios'
} finally {
    Pop-Location
}
