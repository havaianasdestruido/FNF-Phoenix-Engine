# Port of run-menu-checker-textures.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-menu-checker-textures-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/MenuCheckerTextures.hx" "$testSource/backend/MenuCheckerTextures.hx"
    & $haxe -cp $testSource -cp tests/haxe -main MenuCheckerTexturesSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "MenuCheckerTexturesSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
