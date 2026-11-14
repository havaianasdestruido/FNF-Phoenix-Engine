# Port of run-window-mode.sh - keep in sync with the .sh / .bat versions.
# Window display mode (Windowed / Borderless / Fullscreen): normalization,
# persistence, the F11 toggle and the windowed-only interactions, without the
# full Flixel/Lime dependency tree.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-window-mode-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null

function Invoke-Haxe {
    param([string[]]$HaxeArgs)
    & $haxe @HaxeArgs
    if ($LASTEXITCODE -ne 0) { throw "haxe failed ($LASTEXITCODE): $HaxeArgs" }
}

try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/WindowMode.hx" "$testSource/backend/"
    $common = @("-cp", $testSource, "-cp", "tests/haxe/stubs/window-mode", "-cp", "tests/haxe", "-main", "WindowModeSpec")

    # No target define: the sys/interpreter run exercises the shared logic and
    # the non-desktop resize no-op. Then -D desktop exercises the native path.
    Invoke-Haxe ($common + @("--interp"))
    Invoke-Haxe ($common + @("-D", "desktop", "--interp"))

    # The desktop-only resize branch is typechecked (and its C++ inspected) for
    # each native desktop target without invoking hxcpp or producing binaries.
    foreach ($platform in @("windows", "linux", "mac")) {
        $output = "$testSource/generated/$platform"
        Invoke-Haxe ($common + @("-D", "desktop", "-D", $platform, "-D", "no-compilation", "-cpp", $output))
        $generated = "$output/src/backend/WindowMode.cpp"
        if (-not (Select-String -LiteralPath $generated -Pattern 'resizeWindow' -SimpleMatch -Quiet)) {
            throw "resizeWindow missing for $platform"
        }
    }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
