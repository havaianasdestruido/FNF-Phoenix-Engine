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

    # No define: a target that cannot include Lua (mobile, web).
    Invoke-Spec @("--interp")

    # A desktop build without the Lua VM: .lua files are found but cannot run.
    Invoke-Spec @("-D", "desktop", "--interp")

    # A desktop build with the Lua VM.
    Invoke-Spec @("-D", "desktop", "-D", "LUA_ALLOWED", "--interp")
} finally {
    $env:LUA_DIAGNOSTICS_TMP = $previousTmp
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
