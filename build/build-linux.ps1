# Phoenix Engine - Linux release build. Port of build-linux.sh; keep both in sync.
# Extra arguments are passed through to Lime.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    Write-Host '[Phoenix Engine] Building Linux (Release)...'
    & haxelib run lime build linux -release @args
    if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
    Write-Host '[Phoenix Engine] Done. Output: build/release/linux/bin'
} finally {
    Pop-Location
}
