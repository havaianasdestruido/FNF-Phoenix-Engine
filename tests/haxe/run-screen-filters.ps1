# Port of run-screen-filters.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-screen-filters-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
try {
    Copy-Item "tests/haxe/stubs/screen-filters/*" $testSource -Recurse -Force
    Copy-Item "source/backend/ScreenFilters.hx" "$testSource/backend/ScreenFilters.hx"
    Copy-Item "source/backend/ChainableEffects.hx" "$testSource/backend/ChainableEffects.hx"
    & $haxe -cp $testSource -cp tests/haxe -main ScreenFiltersSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
    & $haxe -cp $testSource -cp tests/haxe -main FlxGameFiltersSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }

    # The mirror above only proves the behaviour; this proves the real patch and
    # the three host bindings are still there (a rebase silently drops them).
    $patchFile = "source/source-haxelib-patches/flixel/FlxGame.hx"
    foreach ($needle in @(
        "override function get_filters():Array<BitmapFilter>",
        "override function set_filters(Value:Array<BitmapFilter>):Array<BitmapFilter>",
        "public function applyGameFiltersNow():Void",
        "this.filters = filters;",
        "applyGameFiltersNow();")) {
        if (-not (Select-String -Path $patchFile -SimpleMatch $needle -Quiet)) {
            throw "$patchFile lost `$needle"
        }
    }
    $bindings = @(
        @("source/psychlua/FunkinLua.hx", "FilterCallbacks.register(this)"),
        @("source/psychlua/PythonScript.hx", "PyFilterLib.register(this)"),
        @("source/psychlua/HScript.hx", "FilterCallbacks.seedHScript(interp)"))
    foreach ($binding in $bindings) {
        if (-not (Select-String -Path $binding[0] -SimpleMatch $binding[1] -Quiet)) {
            throw "$($binding[0]) no longer binds the filter API ($($binding[1]))"
        }
    }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
