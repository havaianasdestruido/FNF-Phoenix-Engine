# Port of run-lua-diagnostics.sh - keep in sync with the .sh / .bat versions.
# Contract tests for backend.LuaDiagnostics (docs/LUA_SCRIPT_DEBUGGING.md).
# Set $env:LUAJIT to a LuaJIT binary to add the checks against the real runtime.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-lua-diagnostics-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null

function Invoke-Spec {
    param([string[]]$SpecArgs)
    & $haxe -cp $testSource -cp tests/haxe -main LuaDiagnosticsSpec @SpecArgs
    if ($LASTEXITCODE -ne 0) { throw "LuaDiagnosticsSpec failed ($LASTEXITCODE): $SpecArgs" }
}

$previousTmp = $env:LUA_DIAGNOSTICS_TMP
try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/LuaDiagnostics.hx" "$testSource/backend/LuaDiagnostics.hx"
    $env:LUA_DIAGNOSTICS_TMP = $testSource

    # No define: a target that cannot include Lua (e.g. web).
    Invoke-Spec @("--interp")

    # Desktop or mobile builds without the Lua VM (-DMODDING_LEVEL=0): .lua files are found and rebuild advice is shown.
    Invoke-Spec @("-D", "desktop", "--interp")
    Invoke-Spec @("-D", "mobile", "-D", "android", "--interp")

    # Desktop and mobile builds with the Lua VM (default).
    Invoke-Spec @("-D", "desktop", "-D", "LUA_ALLOWED", "--interp")
    Invoke-Spec @("-D", "mobile", "-D", "android", "-D", "LUA_ALLOWED", "--interp")
} finally {
    $env:LUA_DIAGNOSTICS_TMP = $previousTmp
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
