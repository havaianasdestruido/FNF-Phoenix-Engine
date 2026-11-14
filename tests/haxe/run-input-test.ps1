# Port of run-input-test.sh - keep in sync with the .sh / .bat versions.
# The input tester (phoenix://input) in the Haxe interpreter, without any game
# haxelibs: the renderer-free model first, then the page against the stubs in
# tests/haxe/stubs/input-test.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-input-test-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/logic/backend" -Force | Out-Null
    Copy-Item "source/backend/InputTestLogic.hx" "$testSource/logic/backend/InputTestLogic.hx"
    & $haxe -cp "$testSource/logic" -cp tests/haxe -main InputTestLogicSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "InputTestLogicSpec failed ($LASTEXITCODE)" }
    # The same module typechecked for C++, a static target (nothing is generated).
    & $haxe -cp "$testSource/logic" -cp tests/haxe -main InputTestLogicSpec -cpp "$testSource/cpp" --no-output
    if ($LASTEXITCODE -ne 0) { throw "InputTestLogicSpec does not typecheck for C++ ($LASTEXITCODE)" }

    New-Item -ItemType Directory -Path "$testSource/page" -Force | Out-Null
    Copy-Item "tests/haxe/stubs/input-test/*" "$testSource/page" -Recurse -Force
    New-Item -ItemType Directory -Path "$testSource/page/backend" -Force | Out-Null
    New-Item -ItemType Directory -Path "$testSource/page/states" -Force | Out-Null
    Copy-Item "source/states/InputTestState.hx" "$testSource/page/states/InputTestState.hx"
    foreach ($module in @("InputTestLogic", "InputFormatter", "HardwareKeys", "HoldToConfirmLogic", "ScreenLayout", "TouchlessUI", "AndroidTVPolicy")) {
        Copy-Item "source/backend/$module.hx" "$testSource/page/backend/$module.hx"
    }
    # Flixel defines FLX_TOUCH and FLX_MOUSE unless a project opts out (Phoenix does
    # not), and the page compiles its touch and mouse reads behind them.
    & $haxe -cp "$testSource/page" -cp tests/haxe -D FLX_TOUCH -D FLX_MOUSE -main InputTestStateSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "InputTestStateSpec failed ($LASTEXITCODE)" }
    & $haxe -cp "$testSource/page" -cp tests/haxe -D FLX_TOUCH -D FLX_MOUSE -main InputTestStateSpec -cpp "$testSource/cpp" --no-output
    if ($LASTEXITCODE -ne 0) { throw "InputTestStateSpec does not typecheck for C++ ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
