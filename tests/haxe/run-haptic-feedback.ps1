# Port of run-haptic-feedback.sh - keep in sync with the .sh / .bat versions.
# Automatic note haptics, duration sanitization and Lua/Python vibrate() parity.
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "../..")
$haxe = if ($env:HAXE) { $env:HAXE } else { "haxe" }
$testSource = Join-Path ([IO.Path]::GetTempPath()) ("phoenix-haptic-feedback-" + [Guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $testSource -Force | Out-Null

function Invoke-Spec {
    param([string[]]$SpecArgs)
    & $haxe -cp $testSource -cp tests/haxe -main HapticFeedbackSpec @SpecArgs
    if ($LASTEXITCODE -ne 0) { throw "HapticFeedbackSpec failed ($LASTEXITCODE): $SpecArgs" }
}

try {
    New-Item -ItemType Directory -Path "$testSource/backend" -Force | Out-Null
    New-Item -ItemType Directory -Path "$testSource/play/helpers" -Force | Out-Null
    New-Item -ItemType Directory -Path "$testSource/psychlua/callbacks" -Force | Out-Null
    New-Item -ItemType Directory -Path "$testSource/psychlua/pystdlib" -Force | Out-Null
    Copy-Item "source/backend/HapticFeedback.hx" "$testSource/backend/HapticFeedback.hx"
    Copy-Item "source/backend/PlatformIcons.hx" "$testSource/backend/PlatformIcons.hx"
    Copy-Item "source/backend/PlatformSupport.hx" "$testSource/backend/PlatformSupport.hx"
    Copy-Item "source/play/helpers/PlayStateHaptics.hx" "$testSource/play/helpers/PlayStateHaptics.hx"
    Copy-Item "source/psychlua/callbacks/HardwareCallbacks.hx" "$testSource/psychlua/callbacks/HardwareCallbacks.hx"
    Copy-Item "source/psychlua/pystdlib/PyHardwareLib.hx" "$testSource/psychlua/pystdlib/PyHardwareLib.hx"
    Copy-Item "tests/haxe/stubs/haptics/*" $testSource -Recurse -Force

    Invoke-Spec @("--interp")
    Invoke-Spec @("-D", "android", "--interp")
} finally {
    Remove-Item -LiteralPath $testSource -Recurse -Force -ErrorAction SilentlyContinue
}
