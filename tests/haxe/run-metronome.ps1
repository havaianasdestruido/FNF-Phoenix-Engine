# Port of run-metronome.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-metronome-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$testSource/backend", "$testSource/play/helpers" -Force | Out-Null
try {
    Copy-Item "tests/haxe/stubs/metronome/*" $testSource -Recurse -Force
    Copy-Item "source/backend/Metronome.hx" "$testSource/backend/Metronome.hx"
    Copy-Item "source/play/helpers/PlayStateMetronome.hx" "$testSource/play/helpers/PlayStateMetronome.hx"
    & $haxe -cp $testSource -cp tests/haxe -D FLX_PITCH -main MetronomeSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
    & $haxe -cp $testSource -cp tests/haxe -D FLX_PITCH -main MetronomeSpec -cpp "$testSource/cpp" --no-output
    if ($LASTEXITCODE -ne 0) { throw "haxe cpp typecheck failed ($LASTEXITCODE)" }
    & $haxe -cp $testSource -cp tests/haxe -main MetronomeSpec --swf "$testSource/spec.swf" --no-output
    if ($LASTEXITCODE -ne 0) { throw "haxe swf typecheck failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
