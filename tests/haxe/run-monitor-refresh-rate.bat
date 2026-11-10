@echo off
rem Port of run-monitor-refresh-rate.sh - keep in sync with the .sh / .ps1 versions.
rem Monitor refresh rate helper (Linux X11 query ported from Troll Engine), without
rem the Flixel/Lime dependency tree: behaviour under the interpreter, then the
rem generated C++ per target, without invoking hxcpp or producing binaries.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-refresh-rate-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
copy /y "source\backend\MonitorRefreshRate.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
set COMMON=-cp "%TEST_SOURCE%" -cp tests/haxe/stubs/refresh-rate -cp tests/haxe -main MonitorRefreshRateSpec

%HAXE% %COMMON% --interp || goto fail

rem Desktop Linux must call the native query and pull in its build file; every
rem other target (Android included, which is also Linux) must not reference it.
for %%P in (linux windows mac android) do (
    call :run_platform %%P
    if errorlevel 1 goto fail
)
goto done

:run_platform
set "PLATFORM=%~1"
set "OUTPUT=%TEST_SOURCE%\generated\%PLATFORM%\linux\obj"
set "DEFINES=-D %PLATFORM%"
if /i "%PLATFORM%"=="android" set "DEFINES=-D android -D linux"
%HAXE% %COMMON% %DEFINES% -D no-compilation -cpp "%OUTPUT%"
if errorlevel 1 exit /b 1
if /i "%PLATFORM%"=="linux" goto check_linux
findstr /s /m /l /c:"phoenixMonitorRefreshRate" "%OUTPUT%\src\*" "%OUTPUT%\include\*" >nul
if not errorlevel 1 (
    echo native refresh rate query leaked into the %PLATFORM% build 1>&2
    exit /b 1
)
findstr /l /c:"refresh_rate_build.xml" "%OUTPUT%\Build.xml" >nul
if not errorlevel 1 (
    echo refresh rate build file leaked into the %PLATFORM% build 1>&2
    exit /b 1
)
exit /b 0

:check_linux
findstr /l /c:"phoenixMonitorRefreshRate()" "%OUTPUT%\src\backend\MonitorRefreshRate.cpp" >nul
if errorlevel 1 exit /b 1
findstr /l /c:"phoenix_refresh_rate.h" "%OUTPUT%\src\backend\MonitorRefreshRate.cpp" >nul
if errorlevel 1 exit /b 1
findstr /l /c:"source/backend/native/refresh_rate_build.xml" "%OUTPUT%\Build.xml" >nul
exit /b %ERRORLEVEL%

:done
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
