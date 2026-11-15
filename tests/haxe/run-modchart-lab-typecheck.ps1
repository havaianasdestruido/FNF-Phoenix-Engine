# Port of run-modchart-lab-typecheck.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-modchart-lab-state-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null
try {
    New-Item -ItemType Directory -Path "$testSource/modchart" -Force | Out-Null
    New-Item -ItemType Directory -Path "$testSource/editors" -Force | Out-Null
    Copy-Item "source/modchart/*" "$testSource/modchart/" -Recurse -Force
    Copy-Item "source/editors/ModchartLabState.hx" "$testSource/editors/" -Force
    Copy-Item "tests/haxe/stubs/lab/*" $testSource -Recurse -Force
    & $haxe -cp $testSource -cp tests/haxe -main ModchartLabStateSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "ModchartLabStateSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
