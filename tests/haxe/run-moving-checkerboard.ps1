# Port of run-moving-checkerboard.sh; keep the launchers in sync.
$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$work = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-moving-checkerboard-" + [Guid]::NewGuid().ToString("N"))
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }

try {
    New-Item -ItemType Directory -Force (Join-Path $work "objects") | Out-Null
    Copy-Item (Join-Path $root "source/objects/MovingCheckerboard.hx") (Join-Path $work "objects/MovingCheckerboard.hx")
    Copy-Item (Join-Path $root "tests/haxe/stubs/moving-checkerboard/*") $work -Recurse -Force

    & $haxe -cp $work -cp (Join-Path $root "tests/haxe") -main MovingCheckerboardSpec --interp
    if ($LASTEXITCODE -ne 0) { throw "MovingCheckerboardSpec failed ($LASTEXITCODE)" }
}
finally {
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
