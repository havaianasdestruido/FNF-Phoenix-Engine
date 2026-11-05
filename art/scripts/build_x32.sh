#!/bin/sh
# Port of build_x32.bat - keep in sync with build_x32.bat / build_x32.ps1.
# Original batch assumed it is launched from art/scripts and does `cd ..`.
# Builds the Windows target; on a non-Windows host this needs a Windows
# Lime/HXCPP toolchain, otherwise it will fail the same way the .bat would.
cd .. || exit 1
echo "BUILDING GAME"
threads=${NUMBER_OF_PROCESSORS:-}
if [ -z "$threads" ]; then
    threads=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
fi
haxelib run lime build windows -32 -release -D 32bits -D HXCPP_M32 -D "HXCPP_COMPILE_THREADS=$threads"
echo ""
echo "done."
printf "Press Enter to continue..."
read -r _ || true
pwd
if command -v explorer.exe >/dev/null 2>&1; then
    explorer.exe 'export\32bit\windows\bin'
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open export/32bit/windows/bin 2>/dev/null || echo "export/32bit/windows/bin"
else
    echo "export/32bit/windows/bin"
fi
