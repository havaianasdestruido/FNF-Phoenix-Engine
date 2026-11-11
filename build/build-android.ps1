# Phoenix Engine - Android release build. Port of build-android.sh; keep both
# in sync. Modding level 2 is the default, mobile included. Extra arguments
# are passed through to Lime.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '..')
try {
    Write-Host '[Phoenix Engine] Building Android (Release)...'
    & haxelib run lime build android -release @args
    if ($LASTEXITCODE -ne 0) { throw "Build failed with exit code $LASTEXITCODE" }
    Write-Host '[Phoenix Engine] Done. APK: build/release/android/bin/app/build/outputs/apk'
} finally {
    Pop-Location
}
