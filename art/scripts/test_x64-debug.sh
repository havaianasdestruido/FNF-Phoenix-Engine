#!/bin/sh
# Port of test_x64-debug.bat - keep in sync with test_x64-debug.bat / .ps1.
cd .. || exit 1
echo "BUILDING GAME"
threads=${NUMBER_OF_PROCESSORS:-}
if [ -z "$threads" ]; then
    threads=$(getconf _NPROCESSORS_ONLN 2>/dev/null || echo 1)
fi
haxelib run lime test windows -debug -D "HXCPP_COMPILE_THREADS=$threads"
echo ""
echo "done."
printf "Press Enter to continue..."
read -r _ || true
