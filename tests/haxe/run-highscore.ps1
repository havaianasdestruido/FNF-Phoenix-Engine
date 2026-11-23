# Port of run-highscore.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-highscore-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$work/backend", "$work/data", "$work/flixel" -Force | Out-Null
try {
    Copy-Item "source/backend/Highscore.hx" "$work/backend/Highscore.hx"
    Copy-Item "tests/haxe/stubs/highscore/import.hx" "$work/import.hx"
    Copy-Item "tests/haxe/stubs/highscore/backend/Paths.hx" "$work/backend/Paths.hx"
    Copy-Item "tests/haxe/stubs/highscore/backend/CoolUtil.hx" "$work/backend/CoolUtil.hx"
    Copy-Item "tests/haxe/stubs/highscore/flixel/FlxG.hx" "$work/flixel/FlxG.hx"
    Copy-Item "tests/haxe/stubs/data/Song.hx" "$work/data/Song.hx"
    Copy-Item "tests/haxe/stubs/data/Section.hx" "$work/data/Section.hx"
    & $haxe -cp $work -cp "$repo/tests/haxe" -main HighscoreSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "HighscoreSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
