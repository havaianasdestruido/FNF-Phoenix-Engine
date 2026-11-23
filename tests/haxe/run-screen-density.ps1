# Port of run-screen-density.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-screen-density-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$work/backend", "$work/flixel" -Force | Out-Null
try {
    Copy-Item "source/backend/ScreenDensity.hx" "$work/backend/ScreenDensity.hx"
    Copy-Item "source/backend/PlatformIcons.hx" "$work/backend/PlatformIcons.hx"
    Copy-Item "tests/haxe/stubs/screen-density/flixel/FlxG.hx" "$work/flixel/FlxG.hx"
    & $haxe -cp $work -cp "$repo/tests/haxe" -main ScreenDensitySpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ScreenDensitySpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
