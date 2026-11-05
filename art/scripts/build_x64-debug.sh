#!/bin/sh
# Port of build_x64-debug.bat - keep in sync with build_x64-debug.bat / .ps1.
cd .. || exit 1
echo "BUILDING GAME"
threads=${NUMBER_OF_PROCESSORS:-}
if [ -z "$threads" ]; then
    threads=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
fi
haxelib run lime build windows -debug -D "HXCPP_COMPILE_THREADS=$threads"
echo ""
echo "done."
printf "Press Enter to continue..."
read -r _ || true
pwd
if command -v explorer.exe >/dev/null 2>&1; then
    explorer.exe 'export\debug\windows\bin'
elif command -v xdg-open >/dev/null 2>&1; then
    xdg-open export/debug/windows/bin 2>/dev/null || echo "export/debug/windows/bin"
else
    echo "export/debug/windows/bin"
fi
