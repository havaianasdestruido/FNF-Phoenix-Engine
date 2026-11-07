# Port of run-video-render.sh - keep in sync with the .sh / .bat versions.
# Rendering Mode folders (nested creation, Windows path anchoring) and the
# FFmpeg lookup (game folder, PATH, PHOENIX_FFMPEG, package managers).
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-video-render-" + [Guid]::NewGuid().ToString("N"))
try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    New-Item -ItemType Directory -Path "$testSource/work" -Force | Out-Null
    Copy-Item "source/backend/RenderPaths.hx" "$testSource/backend/RenderPaths.hx"
    Copy-Item "source/backend/FFmpegLocator.hx" "$testSource/backend/FFmpegLocator.hx"
    Push-Location "$testSource/work"
    try {
        & $haxe -cp $testSource -cp $PSScriptRoot -main VideoRenderSpec --interp
        if ($LASTEXITCODE -ne 0) { throw "haxe interp failed ($LASTEXITCODE)" }
    } finally {
        Pop-Location
    }
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
