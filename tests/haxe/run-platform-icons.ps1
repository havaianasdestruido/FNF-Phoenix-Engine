# Port of run-platform-icons.sh - keep in sync with the .sh / .bat versions.
# Platform badge contract: target detection, density math and glyph bounds.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-platform-icons-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null

function Invoke-Spec {
    param([string[]]$SpecArgs)
    & $haxe -cp $testSource -cp tests/haxe -main PlatformIconSpec @SpecArgs
    if ($LASTEXITCODE -ne 0) { throw "PlatformIconSpec failed ($LASTEXITCODE): $SpecArgs" }
}

try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/PlatformIcons.hx" "$testSource/backend/PlatformIcons.hx"

    # No define: the runtime system name decides.
    Invoke-Spec @("--interp")

    foreach ($platform in @("windows", "mac", "linux", "android", "ios", "html5", "air")) {
        Invoke-Spec @("-D", $platform, "--interp")
    }

    # `flash` is a reserved compiler flag: compile for the real target instead.
    Invoke-Spec @("--swf", "$testSource/spec.swf", "--no-output")

    # A real AIR build is the Flash target plus `air`.
    Invoke-Spec @("-D", "air", "--swf", "$testSource/spec.swf", "--no-output")
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
