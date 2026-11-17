# Port of run-commit-freshness.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("commit-freshness-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/CommitFreshness.hx" "$testSource/backend/"
    Copy-Item "source/backend/HaxeCommit.hx" "$testSource/backend/"
    & $haxe -cp $testSource -cp tests/haxe -main CommitFreshnessSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
    # Both sides of `#if commit`: unstamped builds keep the null fallback,
    # stamped builds embed this checkout's hash.
    & $haxe -cp $testSource -cp tests/haxe -main CommitStampSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
    & $haxe -cp $testSource -cp tests/haxe -main CommitStampSpec -D commit --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
