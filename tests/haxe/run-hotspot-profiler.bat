@echo off
rem Port of run-hotspot-profiler.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-hotspot-profiler-%RANDOM%-%RANDOM%"
mkdir "%WORK%\debug\profiler" || exit /b 1
copy /y "source\debug\profiler\HotspotProfiler.hx" "%WORK%\debug\profiler\" >nul || goto fail
copy /y "tests\haxe\stubs\hotspot-profiler\debug\FrameProfiler.hx" "%WORK%\debug\" >nul || goto fail
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main HotspotProfilerSpec --interp || goto fail
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
