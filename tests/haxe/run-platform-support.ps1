# Port of run-platform-support.sh - keep in sync with the .sh / .bat versions.
# Platform gating contract: tags, requirement lists, aliases and registries.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-platform-support-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null

function Invoke-Spec {
    param([string[]]$SpecArgs)
    & $haxe -cp $testSource -cp tests/haxe -main PlatformSupportSpec @SpecArgs
    if ($LASTEXITCODE -ne 0) { throw "PlatformSupportSpec failed ($LASTEXITCODE): $SpecArgs" }
}

try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    Copy-Item "source/backend/PlatformIcons.hx" "$testSource/backend/PlatformIcons.hx"
    Copy-Item "source/backend/PlatformSupport.hx" "$testSource/backend/PlatformSupport.hx"

    # No define: the `sys`/host fallback.
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
