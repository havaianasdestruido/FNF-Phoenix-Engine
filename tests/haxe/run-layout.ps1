# Port of run-layout.sh - keep in sync with the .sh / .bat versions.
# Isolate dependency-free production modules from source/import.hx's
# Flixel/OpenFL imports; these tests run without game haxelibs.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-layout-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/backend", "$testSource/mobile/flixel" -Force | Out-Null
    Copy-Item "source/backend/ScreenLayout.hx" "$testSource/backend/ScreenLayout.hx"
    Copy-Item "source/backend/ModSecurity.hx" "$testSource/backend/ModSecurity.hx"
    Copy-Item "source/backend/ScriptSecurityScanner.hx" "$testSource/backend/ScriptSecurityScanner.hx"
    Copy-Item "source/mobile/flixel/HitboxTouchLogic.hx" "$testSource/mobile/flixel/HitboxTouchLogic.hx"
    & $haxe -cp $testSource -cp tests/haxe -main LayoutSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "LayoutSpec failed ($LASTEXITCODE)" }
    & $haxe -cp $testSource -cp tests/haxe -main ModSecuritySpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ModSecuritySpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
