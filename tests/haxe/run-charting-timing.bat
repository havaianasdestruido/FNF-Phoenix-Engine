@echo off
rem Port of run-charting-timing.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-charting-timing-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\editors\charting" "%TEST_SOURCE%\backend" "%TEST_SOURCE%\data" "%TEST_SOURCE%\objects" "%TEST_SOURCE%\play" || exit /b 1
copy /y "source\editors\charting\ChartingTiming.hx" "%TEST_SOURCE%\editors\charting\" >nul || goto fail
copy /y "source\backend\Conductor.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\backend\ClientPrefs.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\data\Section.hx" "%TEST_SOURCE%\data\" >nul || goto fail
copy /y "tests\haxe\stubs\data\Song.hx" "%TEST_SOURCE%\data\" >nul || goto fail
copy /y "tests\haxe\stubs\objects\Note.hx" "%TEST_SOURCE%\objects\" >nul || goto fail
copy /y "tests\haxe\stubs\objects\NoteSplash.hx" "%TEST_SOURCE%\objects\" >nul || goto fail
copy /y "tests\haxe\stubs\play\PlayState.hx" "%TEST_SOURCE%\play\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ChartingTimingSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
