@echo off
rem Port of run-chart-loader.sh - keep in sync with the .sh / .ps1 versions.
rem Exercise the production gameplay chart loader with renderer-free stubs.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-chart-loader-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%" || exit /b 1
xcopy /e /i /y /q "tests\haxe\stubs\chart-loader" "%TEST_SOURCE%" >nul || goto fail
mkdir "%TEST_SOURCE%\play\helpers" 2>nul
copy /y "source\play\helpers\PlayStateChartLoader.hx" "%TEST_SOURCE%\play\helpers\PlayStateChartLoader.hx" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ChartLoaderSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ChartLoaderSpec -js "%TEST_SOURCE%\chart-loader.js" || goto fail
node "%TEST_SOURCE%\chart-loader.js" || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
