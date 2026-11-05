@echo off
rem Port of run-pool-stats.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-pool-stats-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\debug" || exit /b 1
copy /y "source\debug\PoolStats.hx" "%TEST_SOURCE%\debug\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main PoolStatsSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
