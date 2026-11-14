# Port of run-hold-to-confirm.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-hold-confirm-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/HoldToConfirmLogic.hx" "$testSource/backend/HoldToConfirmLogic.hx"
    & $haxe -cp $testSource -cp tests/haxe -main HoldToConfirmSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "HoldToConfirmSpec failed ($LASTEXITCODE)" }
    # The same module typechecked for C++, a static target (nothing is generated).
    & $haxe -cp $testSource -cp tests/haxe -main HoldToConfirmSpec -cpp "$testSource/cpp" --no-output
    if ($LASTEXITCODE -ne 0) { throw "HoldToConfirmSpec does not typecheck for C++ ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
