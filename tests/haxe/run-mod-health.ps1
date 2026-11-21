# Port of run-mod-health.sh - keep in sync with the .sh / .bat versions.
# The per-mod "why did it break?" report: ModHealth itself, then the
# Mods.getPack() half against the small stubs in tests/haxe/stubs/mod-pack.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$repo = (Get-Location).Path
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-mod-health-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $work -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$work/backend", "$work/states/helpers", "$work/pack/backend" -Force | Out-Null
    Copy-Item "source/backend/ModHealth.hx" "$work/backend/ModHealth.hx"
    Copy-Item "source/backend/ModPathPolicy.hx" "$work/backend/ModPathPolicy.hx"
    Copy-Item "source/states/helpers/ModInfoFlow.hx" "$work/states/helpers/ModInfoFlow.hx"

    # 1. The report itself: recording, severity, summary and the Mod Info block.
    & $haxe -cp $work -cp "$repo/tests/haxe" -main ModHealthSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ModHealthSpec failed ($LASTEXITCODE)" }

    # 2. The manifest half reads the real backend/Mods.hx inside a throwaway tree.
    Copy-Item "source/backend/Mods.hx" "$work/pack/backend/Mods.hx"
    Copy-Item "source/backend/ModsList.hx" "$work/pack/backend/ModsList.hx"
    Copy-Item "source/backend/ModHealth.hx" "$work/pack/backend/ModHealth.hx"
    Copy-Item "source/backend/ModPathPolicy.hx" "$work/pack/backend/ModPathPolicy.hx"
    Set-Content -Path "$work/pack/import.hx" -Value @(
        "#if !macro",
        "import sys.FileSystem;",
        "import sys.io.File;",
        "using StringTools;",
        "#end"
    )
    Push-Location "$work/pack"
    try {
        & $haxe -cp "$work/pack" -cp "$repo/tests/haxe/stubs/mod-pack" -cp "$repo/tests/haxe" `
            -main ModPackHealthSpec -D MODS_ALLOWED --interp
        if ($LASTEXITCODE -ne 0) { throw "ModPackHealthSpec failed ($LASTEXITCODE)" }
    } finally { Pop-Location }
} finally {
    Remove-Item -LiteralPath $work -Recurse -Force -ErrorAction SilentlyContinue
}
