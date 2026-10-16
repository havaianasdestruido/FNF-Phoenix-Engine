# Ensures the hxcpp haxelib is set to the git checkout (FunkinCrew fork)
# that setup\windows.bat installs. The git version is REQUIRED on Windows MSVC:
#
#   * It supports hxcpp's <assembler> element, so libffi's .asm files (used by
#     hxluau) get assembled with ml64.exe. hxcpp 4.3.2 lacks this -> the .asm
#     files are silently ignored -> linker error LNK1181 "win64.obj".
#   * It honors the HXCPP_CPP17 haxedef that hxluau's haxelib.json emits, so
#     Luau sources are compiled with /std:c++17. hxcpp 4.3.2 ignores that
#     define and uses MSVC's default (C++14) -> errors C7525 / C2039 on
#     std::string_view and inline variables.
#
# A later `haxelib install <something>` can flip the active hxcpp back to a
# release such as 4.3.2; this script restores the intended git checkout.
#
# Idempotent. Run AFTER setup\windows.bat, before building.
# Usage (from repo root):
#   powershell -ExecutionPolicy Bypass -File setup\windows-msvc-fix.ps1

$ErrorActionPreference = 'Stop'

$out = (& haxelib list hxcpp 2>&1) -join "`n"
if ($out -match '\[git\]') {
    Write-Host "hxcpp already set to git. OK."
} elseif ($out -match 'git') {
    Write-Host "Setting hxcpp to git..."
    & haxelib set hxcpp git | Out-Null
    Write-Host "hxcpp set to git. OK."
} else {
    Write-Error "hxcpp git checkout not found in haxelib. Run setup\windows.bat first (it installs hxcpp from the FunkinCrew fork)."
    exit 1
}

# Verify that the checked-out hxcpp actually comes from the expected fork.
$hxcppPath = (& haxelib path hxcpp 2>&1) -split "`n" | Where-Object { $_.Trim() -ne '' } | Select-Object -Last 1
$hxcppPath = $hxcppPath.Trim()
if (Test-Path (Join-Path $hxcppPath '.git')) {
    $remote = (& git -C $hxcppPath remote get-url origin 2>&1) -join "`n"
    if ($remote -notmatch 'FunkinCrew/hxcpp') {
        Write-Error "hxcpp git checkout points at an unexpected remote ($remote). Expected https://github.com/FunkinCrew/hxcpp."
        exit 1
    }
} else {
    Write-Error "hxcpp path is not a git checkout: $hxcppPath"
    exit 1
}

Write-Host "`nDone. Build with: lime build windows -DMODDING_LEVEL=2"
