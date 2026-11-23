# Port of run-state-scripts.sh - keep in sync with the .sh / .bat versions.
# The spec builds its fixture tree under the working directory.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-state-scripts-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$work/psychlua", "$work/backend", "$work/lime/utils", "$work/openfl/utils" -Force | Out-Null
try {
    Copy-Item "source/psychlua/StateScripts.hx" "$work/psychlua/StateScripts.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/import.hx" "$work/import.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/backend/Paths.hx" "$work/backend/Paths.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/backend/RuntimeFlags.hx" "$work/backend/RuntimeFlags.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/backend/Mods.hx" "$work/backend/Mods.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/lime/utils/Assets.hx" "$work/lime/utils/Assets.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/openfl/utils/Assets.hx" "$work/openfl/utils/Assets.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/psychlua/HaxeScript.hx" "$work/psychlua/HaxeScript.hx"
    New-Item -ItemType Directory -Path "$work/flixel/addons/transition", "$work/states/substates" -Force | Out-Null
    Copy-Item "tests/haxe/stubs/state-scripts/flixel/FlxG.hx" "$work/flixel/FlxG.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/flixel/addons/transition/FlxTransitionableState.hx" "$work/flixel/addons/transition/FlxTransitionableState.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/states/ModState.hx" "$work/states/ModState.hx"
    Copy-Item "tests/haxe/stubs/state-scripts/states/substates/ModSubState.hx" "$work/states/substates/ModSubState.hx"
    New-Item -ItemType Directory -Path "$work/states" -Force | Out-Null
    Copy-Item "tests/haxe/stubs/state-scripts/fixtures/states/NestedFixture.hx" "$work/states/NestedFixture.hx"
    Push-Location $work
    try {
        & $haxe -cp $work -cp "$repo/tests/haxe" -D MODS_ALLOWED -D HSCRIPT_ALLOWED -main StateScriptsSpec --interp
        if ($LASTEXITCODE -ne 0) { throw "StateScriptsSpec failed ($LASTEXITCODE)" }
    } finally { Pop-Location }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
