# Port of run-benchmark.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-benchmark-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
New-Item -ItemType Directory -Path "$testSource/lime/system" -Force | Out-Null
try {
    Copy-Item "source/backend/BenchmarkChart.hx" "$testSource/backend/BenchmarkChart.hx"
    Copy-Item "source/backend/RecoveryBoot.hx" "$testSource/backend/RecoveryBoot.hx"
    Set-Content -Path "$testSource/lime/system/System.hx" -Value "package lime.system;`n/** Test stub: RecoveryBoot only reads the application storage directory. */`nclass System { public static var applicationStorageDirectory:String = '$env:TEMP\\'; }"
    Set-Content -Path "$testSource/backend/Benchmark.hx" -Value "package backend;`n/** Test stub: only the flag the mod-suppression predicate reads. */`nclass Benchmark { public static var active:Bool = false; }"
    & $haxe -cp $testSource -cp tests/haxe -main BenchmarkSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
