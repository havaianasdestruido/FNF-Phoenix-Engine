# Port of run-modchart-typecheck.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-modchart-runtime-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    foreach ($dir in @("modchart", "play/helpers", "psychlua/callbacks", "psychlua/pystdlib")) {
        New-Item -ItemType Directory -Path (Join-Path $testSource $dir) -Force | Out-Null
    }
    Copy-Item "source/modchart/*" (Join-Path $testSource "modchart") -Recurse -Force
    Copy-Item "source/play/helpers/PlayStateModchart.hx" (Join-Path $testSource "play/helpers") -Force
    Copy-Item "source/psychlua/callbacks/ModchartCallbacks.hx" (Join-Path $testSource "psychlua/callbacks") -Force
    Copy-Item "source/psychlua/pystdlib/PyModchartLib.hx" (Join-Path $testSource "psychlua/pystdlib") -Force
    Copy-Item "tests/haxe/stubs/modchart/*" $testSource -Recurse -Force
    & $haxe -cp $testSource -cp tests/haxe -main ModchartRuntimeSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ModchartRuntimeSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
