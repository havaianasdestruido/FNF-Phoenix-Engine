# Port of android-copy-stl.sh / android-copy-stl.bat - keep the three in sync.
# Copy the Android NDK's libc++_shared.so into the generated Gradle project.
# See android-copy-stl.sh for the full rationale (liblime.so is linked against
# the shared C++ runtime and nothing else copies it into the APK).
# Usage:
#   android-copy-stl.ps1 [--ndk <ndk-root>] <jniLibs-dir> <abi> [<abi> ...]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$RemainingArgs
)
$ErrorActionPreference = "Stop"
$Program = Split-Path -Leaf $PSCommandPath

function Show-Usage {
    Write-Host "Usage: $Program [--ndk <ndk-root>] <jniLibs-dir> <abi> [<abi> ...]"
    Write-Host ""
    Write-Host "Copies libc++_shared.so from the Android NDK into <jniLibs-dir>\<abi>\."
    Write-Host "Recognised ABIs: arm64-v8a, armeabi-v7a, x86_64, x86"
}

$NdkRoot = ""
$JniLibsDir = ""
$Abis = @()
for ($i = 0; $i -lt $RemainingArgs.Count; $i++) {
    switch -Regex ($RemainingArgs[$i]) {
        '^--ndk$' {
            if ($i + 1 -ge $RemainingArgs.Count) { Write-Host "$Program`: --ndk needs a value" -ForegroundColor Red; exit 2 }
            $NdkRoot = $RemainingArgs[++$i]
        }
        '^(-h|--help)$' { Show-Usage; exit 0 }
        default {
            if ([string]::IsNullOrEmpty($JniLibsDir)) { $JniLibsDir = $RemainingArgs[$i] } else { $Abis += $RemainingArgs[$i] }
        }
    }
}

if ([string]::IsNullOrEmpty($JniLibsDir) -or $Abis.Count -eq 0) { Show-Usage; exit 2 }

function Get-LimeConfigValue([string]$Name) {
    $cfg = $env:LIME_CONFIG
    if ([string]::IsNullOrEmpty($cfg)) {
        foreach ($homeDir in @($env:HOME, $env:USERPROFILE)) {
            if ($homeDir -and (Test-Path (Join-Path $homeDir ".lime/config.xml"))) {
                $cfg = Join-Path $homeDir ".lime/config.xml"; break
            }
        }
    }
    if ([string]::IsNullOrEmpty($cfg) -or -not (Test-Path -LiteralPath $cfg)) { return $null }
    foreach ($line in Get-Content -LiteralPath $cfg) {
        if ($line -match "<set(?:env)? name=`"$Name`" value=`"([^`"]*)`"") { $value = $Matches[1] }
    }
    return $value
}

# Resolve the NDK: explicit argument, then environment, then Lime's config.
if ($NdkRoot -and -not (Test-Path -LiteralPath $NdkRoot)) {
    Write-Host "$Program`: ignoring --ndk `"$NdkRoot`" (no such directory)" -ForegroundColor Yellow
    $NdkRoot = ""
}
if (-not $NdkRoot -and $env:ANDROID_NDK_ROOT -and (Test-Path -LiteralPath $env:ANDROID_NDK_ROOT)) {
    $NdkRoot = $env:ANDROID_NDK_ROOT
}
if (-not $NdkRoot) { $NdkRoot = Get-LimeConfigValue "ANDROID_NDK_ROOT" }
if (-not $NdkRoot -or -not (Test-Path -LiteralPath $NdkRoot)) {
    Write-Host "$Program`: cannot find the Android NDK." -ForegroundColor Red
    Write-Host "  Set ANDROID_NDK_ROOT, pass --ndk <path>, or run 'lime setup android'." -ForegroundColor Red
    exit 1
}

Write-Host "$Program`: NDK $NdkRoot"

$triples = @{
    "arm64-v8a"   = "aarch64-linux-android"
    "armeabi-v7a" = "arm-linux-androideabi"
    "x86_64"      = "x86_64-linux-android"
    "x86"         = "i686-linux-android"
}

foreach ($abi in $Abis) {
    if (-not $triples.ContainsKey($abi)) {
        Write-Host "$Program`: unknown ABI `"$abi`", skipping" -ForegroundColor Yellow
        continue
    }
    $triple = $triples[$abi]
    $src = $null

    # NDK r23 and newer: unified sysroot, any host folder spelling.
    $prebuilt = Join-Path $NdkRoot "toolchains/llvm/prebuilt"
    if (Test-Path -LiteralPath $prebuilt) {
        $candidate = Get-ChildItem -LiteralPath $prebuilt -Directory -ErrorAction SilentlyContinue |
            ForEach-Object { Join-Path $_.FullName "sysroot/usr/lib/$triple/libc++_shared.so" } |
            Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
        if ($candidate) { $src = $candidate }
    }
    # NDK r18-r22: the STL was a separate download under sources/.
    if (-not $src) {
        $legacy = Join-Path $NdkRoot "sources/cxx-stl/llvm-libc++/libs/$abi/libc++_shared.so"
        if (Test-Path -LiteralPath $legacy) { $src = $legacy }
    }
    if (-not $src) {
        Write-Host "$Program`: libc++_shared.so for `"$abi`" not found under $NdkRoot" -ForegroundColor Red
        Write-Host "  Looked in toolchains/llvm/prebuilt/*/sysroot/usr/lib/$triple/ and" -ForegroundColor Red
        Write-Host "  sources/cxx-stl/llvm-libc++/libs/$abi/" -ForegroundColor Red
        exit 1
    }

    $destDir = Join-Path $JniLibsDir $abi
    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    Copy-Item -LiteralPath $src -Destination (Join-Path $destDir "libc++_shared.so") -Force
    Write-Host "$Program`: lib/$abi/libc++_shared.so <- $src"
}
