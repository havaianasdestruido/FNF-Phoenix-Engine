# Port of run-mod-security.sh - keep in sync with the .sh / .bat versions.
# ModSecurity policy and the per-mod switch of Mod Info in the Mods menu.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-mod-security-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$work/backend", "$work/states/helpers" -Force | Out-Null
    Copy-Item "source/backend/ModSecurity.hx" "$work/backend/ModSecurity.hx"
    Copy-Item "source/backend/ScriptSecurityScanner.hx" "$work/backend/ScriptSecurityScanner.hx"
    Copy-Item "source/states/helpers/ModInfoFlow.hx" "$work/states/helpers/ModInfoFlow.hx"

    # 1. Dependency-free contract: without MODS_ALLOWED nothing is read or written.
    & $haxe -cp $work -cp tests/haxe -main ModSecuritySpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ModSecuritySpec failed ($LASTEXITCODE)" }

    # 2. Logic of the Mod Info panel: switching off needs an explicit "Yes", and a
    #    mod cannot write into the panel through its name or its pack.json.
    & $haxe -cp $work -cp tests/haxe -main ModInfoFlowSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ModInfoFlowSpec failed ($LASTEXITCODE)" }

    # 3. MODS_ALLOWED build with a stub backend.Mods. modSecurity.txt is relative to
    #    the working directory, so run inside the throwaway folder.
    Push-Location $work
    try {
        & $haxe -cp $work -cp "$repo/tests/haxe/stubs/mod-security" -cp "$repo/tests/haxe" -main ModSecurityPlayerSpec -D MODS_ALLOWED --interp
        if ($LASTEXITCODE -ne 0) { throw "ModSecurityPlayerSpec failed ($LASTEXITCODE)" }
    } finally { Pop-Location }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
