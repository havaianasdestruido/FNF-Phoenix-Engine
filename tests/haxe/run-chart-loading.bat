@echo off
rem Port of run-chart-loading.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-chart-loading-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%" || exit /b 1
xcopy /e /i /y /q "tests\haxe\stubs\chart-loading" "%TEST_SOURCE%" >nul || goto fail
mkdir "%TEST_SOURCE%\data" 2>nul
copy /y "source\data\Song.hx" "%TEST_SOURCE%\data\Song.hx" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ChartLoadingSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ChartLoadingSpec -js "%TEST_SOURCE%\chart-loading.js" || goto fail
node "%TEST_SOURCE%\chart-loading.js" || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
