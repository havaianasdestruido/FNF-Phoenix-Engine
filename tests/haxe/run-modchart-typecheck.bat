@echo off
rem Port of run-modchart-typecheck.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-modchart-runtime-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\modchart" || exit /b 1
mkdir "%TEST_SOURCE%\play\helpers" || goto fail
mkdir "%TEST_SOURCE%\psychlua\callbacks" || goto fail
mkdir "%TEST_SOURCE%\psychlua\pystdlib" || goto fail
xcopy /s /e /y "source\modchart\*" "%TEST_SOURCE%\modchart\" >nul || goto fail
copy /y "source\play\helpers\PlayStateModchart.hx" "%TEST_SOURCE%\play\helpers\" >nul || goto fail
copy /y "source\psychlua\callbacks\ModchartCallbacks.hx" "%TEST_SOURCE%\psychlua\callbacks\" >nul || goto fail
copy /y "source\psychlua\pystdlib\PyModchartLib.hx" "%TEST_SOURCE%\psychlua\pystdlib\" >nul || goto fail
xcopy /s /e /y "tests\haxe\stubs\modchart\*" "%TEST_SOURCE%\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ModchartRuntimeSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
