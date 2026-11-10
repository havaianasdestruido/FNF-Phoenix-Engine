# Port of run-monitor-refresh-rate.sh - keep in sync with the .sh / .bat versions.
# Monitor refresh rate helper (Linux X11 query ported from Troll Engine), without
# the Flixel/Lime dependency tree: behaviour under the interpreter, then the
# generated C++ per target, without invoking hxcpp or producing binaries.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-refresh-rate-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null

function Invoke-Haxe {
    param([string[]]$HaxeArgs)
    & $haxe @HaxeArgs
    if ($LASTEXITCODE -ne 0) { throw "haxe failed ($LASTEXITCODE): $HaxeArgs" }
}

try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/MonitorRefreshRate.hx" "$testSource/backend/"
    $common = @("-cp", $testSource, "-cp", "tests/haxe/stubs/refresh-rate", "-cp", "tests/haxe", "-main", "MonitorRefreshRateSpec")

    Invoke-Haxe ($common + @("--interp"))

    # Desktop Linux must call the native query and pull in its build file; every
    # other target (Android included, which is also Linux) must not reference it.
    foreach ($platform in @("linux", "windows", "mac", "android")) {
        $output = "$testSource/generated/$platform/linux/obj"
        $defines = @("-D", $platform)
        if ($platform -eq "android") { $defines += @("-D", "linux") }
        Invoke-Haxe ($common + $defines + @("-D", "no-compilation", "-cpp", $output))
        $generated = "$output/src/backend/MonitorRefreshRate.cpp"
        $buildXml = "$output/Build.xml"
        if ($platform -eq "linux") {
            if (-not (Select-String -LiteralPath $generated -Pattern 'phoenixMonitorRefreshRate()' -SimpleMatch -Quiet)) {
                throw "native refresh rate call missing for linux"
            }
            if (-not (Select-String -LiteralPath $generated -Pattern '#include "phoenix_refresh_rate.h"' -SimpleMatch -Quiet)) {
                throw "phoenix_refresh_rate.h include missing for linux"
            }
            if (-not (Select-String -LiteralPath $buildXml -Pattern 'source/backend/native/refresh_rate_build.xml' -SimpleMatch -Quiet)) {
                throw "refresh_rate_build.xml include missing for linux"
            }
        } else {
            $sources = Get-ChildItem -Path "$output/src", "$output/include" -Recurse -File
            if ($sources | Select-String -Pattern 'phoenixMonitorRefreshRate' -SimpleMatch -Quiet) {
                throw "native refresh rate query leaked into the $platform build"
            }
            if (Select-String -LiteralPath $buildXml -Pattern 'refresh_rate_build.xml' -SimpleMatch -Quiet) {
                throw "refresh rate build file leaked into the $platform build"
            }
        }
    }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
