# Phoenix Engine - macOS release build. Port of build-mac.sh; keep both in sync.
# Extra arguments are passed through to Lime.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    Write-Host '[Phoenix Engine] Building macOS (Release)...'
    & haxelib run lime build mac -release @args
    if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
    Write-Host '[Phoenix Engine] Done. Output: build/release/mac/bin'
} finally {
    Pop-Location
}
