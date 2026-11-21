# Port of run-stage-editor.sh - keep in sync with the .sh / .bat versions.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-stage-editor-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path "$testSource/data" -Force | Out-Null
try {
    Copy-Item "source/data/StageEditorCore.hx" "$testSource/data/" -Force
    Copy-Item "source/data/StageUndoStack.hx" "$testSource/data/" -Force
    & $haxe -cp $testSource -cp tests/haxe -main StageEditorSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "StageEditorSpec failed ($LASTEXITCODE)" }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
