# Port of run-phoenix-version.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-version-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/PhoenixVersion.hx", "source/backend/PhoenixReleases.hx" "$testSource/backend/"
    & $haxe -cp $testSource -cp tests/haxe -main PhoenixVersionSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
