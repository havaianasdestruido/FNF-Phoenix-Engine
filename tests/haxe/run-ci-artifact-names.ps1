# Port of run-ci-artifact-names.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = 'Stop'
Push-Location (Join-Path $PSScriptRoot '../..')
try {
    $haxe = if ($env:HAXE) { $env:HAXE } else { 'haxe' }
    & $haxe -cp tests/haxe -main CIArtifactNamesSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "CIArtifactNamesSpec failed ($LASTEXITCODE)" }
} finally {
    Pop-Location
}
