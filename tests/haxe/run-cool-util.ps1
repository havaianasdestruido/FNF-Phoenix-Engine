# Port of run-cool-util.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-cool-util-" + [Guid]::NewGuid().ToString("N"))
$dirs = @("backend", "data", "objects", "play", "shaders", "lime/system", "utils")
foreach ($d in $dirs) {
    New-Item -ItemType Directory -Path (Join-Path $work $d) -Force | Out-Null
}
try {
    Copy-Item "source/backend/CoolUtil.hx" "$work/backend/CoolUtil.hx"
    Copy-Item "source/backend/Conductor.hx" "$work/backend/Conductor.hx"
    Copy-Item "source/backend/PhoenixVersion.hx" "$work/backend/PhoenixVersion.hx"
    Copy-Item "tests/haxe/stubs/cool-util/import.hx" "$work/import.hx"
    Copy-Item "tests/haxe/stubs/cool-util/Main.hx" "$work/Main.hx"
    Copy-Item "tests/haxe/stubs/cool-util/backend/*.hx" "$work/backend/"
    Copy-Item "tests/haxe/stubs/cool-util/flixel" "$work/flixel" -Recurse
    Copy-Item "tests/haxe/stubs/cool-util/objects/*.hx" "$work/objects/"
    Copy-Item "tests/haxe/stubs/cool-util/shaders" "$work/shaders" -Recurse
    Copy-Item "tests/haxe/stubs/cool-util/lime" "$work/lime" -Recurse
    Copy-Item "tests/haxe/stubs/cool-util/openfl" "$work/openfl" -Recurse
    Copy-Item "tests/haxe/stubs/cool-util/utils/CoolSystemStuff.hx" "$work/utils/CoolSystemStuff.hx"
    Copy-Item "tests/haxe/stubs/backend/ClientPrefs.hx" "$work/backend/ClientPrefs.hx"
    Copy-Item "tests/haxe/stubs/data/Song.hx" "$work/data/Song.hx"
    Copy-Item "tests/haxe/stubs/data/Section.hx" "$work/data/Section.hx"
    Copy-Item "tests/haxe/stubs/objects/Note.hx" "$work/objects/Note.hx"
    Copy-Item "tests/haxe/stubs/objects/NoteSplash.hx" "$work/objects/NoteSplash.hx"
    Copy-Item "tests/haxe/stubs/play/PlayState.hx" "$work/play/PlayState.hx"
    & $haxe -cp $work -cp "$repo/tests/haxe" -main CoolUtilSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "CoolUtilSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
