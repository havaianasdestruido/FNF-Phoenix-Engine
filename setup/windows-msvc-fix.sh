#!/bin/sh
# Port of windows-msvc-fix.ps1 - keep in sync with the .ps1 / .bat versions.
# Ensures hxcpp is set to the FunkinCrew git checkout setup/windows.bat
# installs (required for MSVC). The haxelib/git checks themselves are
# platform-independent, so this runs under Git Bash on Windows as-is; the
# MSVC failure it prevents only occurs on Windows.
set -eu

expected_remote='https://github.com/FunkinCrew/hxcpp'

hxcpp_path=$(haxelib path hxcpp 2>/dev/null | sed -n '1p' || true)
if [ -n "$hxcpp_path" ] && [ -d "$hxcpp_path/.git" ]; then
    actual_remote=$(git -C "$hxcpp_path" remote get-url origin 2>/dev/null || true)
    case "$actual_remote" in
        *FunkinCrew/hxcpp) echo "hxcpp remote verified: $actual_remote" ;;
        *)
            echo "hxcpp checkout at $hxcpp_path points at '$actual_remote', expected '$expected_remote' (see hmm.json). Re-run setup/windows.bat." >&2
            exit 1
            ;;
    esac
fi

out=$(haxelib list hxcpp 2>&1 || true)
case "$out" in
    *'[git]'*)
        echo "hxcpp already set to git. OK."
        ;;
    *git*)
        echo "Setting hxcpp to git..."
        haxelib set hxcpp git >/dev/null
        echo "hxcpp set to git. OK."
        ;;
    *)
        echo "hxcpp git checkout not found in haxelib. Run setup/windows.bat first (it installs hxcpp from the FunkinCrew fork)." >&2
        exit 1
        ;;
esac

echo ""
echo "Done. Build with: lime build windows -DMODDING_LEVEL=2"
