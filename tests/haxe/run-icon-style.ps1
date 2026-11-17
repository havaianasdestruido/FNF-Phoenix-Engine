# Port of run-icon-style.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-icon-style-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/IconStyle.hx" "$testSource/backend/IconStyle.hx"
    & $haxe -cp $testSource -cp tests/haxe -main IconStyleSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "IconStyleSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
