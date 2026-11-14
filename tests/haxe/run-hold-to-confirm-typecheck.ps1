# Port of run-hold-to-confirm-typecheck.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-hold-confirm-flixel-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    Copy-Item "tests/haxe/stubs/hold-confirm/*" $testSource -Recurse -Force
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    New-Item -ItemType Directory -Path "$testSource/objects" -Force | Out-Null
    Copy-Item "source/backend/HoldToConfirmLogic.hx" "$testSource/backend/HoldToConfirmLogic.hx"
    Copy-Item "source/objects/TouchTarget.hx" "$testSource/objects/TouchTarget.hx"
    Copy-Item "source/objects/HoldToConfirm.hx" "$testSource/objects/HoldToConfirm.hx"
    & $haxe -cp $testSource -cp tests/haxe -D FLX_TOUCH -main HoldToConfirmTypecheck --interp
    if ($LASTEXITCODE -ne 0) { throw "HoldToConfirmTypecheck failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
