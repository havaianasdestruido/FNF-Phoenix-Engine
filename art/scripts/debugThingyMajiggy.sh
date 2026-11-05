#!/bin/sh
# Port of debugThingyMajiggy.bat - keep in sync with the .bat / .ps1 versions.
# The batch file's `cd ...` is the old cmd idiom for "up two levels".
cd ../.. || exit 1
echo "Are you sure you want to Debug by terminal?"
echo ""
echo "Press any key if you want to continue. If not, close this."
sleep 10
echo ""
echo "Opening Debug Terminal..."
echo "------------------------------"
if [ -f "./FNF-Phoenix-Engine.exe" ]; then
    ./FNF-Phoenix-Engine.exe
elif [ -f "./FNF-Phoenix-Engine" ]; then
    ./FNF-Phoenix-Engine
else
    echo "FNF-Phoenix-Engine executable not found in $(pwd)." >&2
fi
echo ""
echo "------------------------------"
echo ""
echo "Look like the game closed... Closing in 10 seconds."
sleep 10
