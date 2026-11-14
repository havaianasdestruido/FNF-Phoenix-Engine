@echo off
rem Port of run-window-mode.sh - keep in sync with the .sh / .ps1 versions.
rem Window display mode (Windowed / Borderless / Fullscreen): normalization,
rem persistence, the F11 toggle and the windowed-only interactions, without the
rem full Flixel/Lime dependency tree.
setlocal EnableExtensions EnableDelayedExpansion
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-window-mode-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
copy /y "source\backend\WindowMode.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
set COMMON=-cp "%TEST_SOURCE%" -cp tests/haxe/stubs/window-mode -cp tests/haxe -main WindowModeSpec

rem No target define: the sys/interpreter run exercises the shared logic and the
rem non-desktop resize no-op. Then -D desktop exercises the native window path.
%HAXE% %COMMON% --interp || goto fail
%HAXE% %COMMON% -D desktop --interp || goto fail

rem The desktop-only resize branch is typechecked (and its C++ inspected) for
rem each native desktop target without invoking hxcpp or producing binaries.
for %%P in (windows linux mac) do (
    call :run_platform %%P
    if errorlevel 1 goto fail
)
goto done

:run_platform
set "PLATFORM=%~1"
set "OUTPUT=%TEST_SOURCE%\generated\%PLATFORM%"
%HAXE% %COMMON% -D desktop -D %PLATFORM% -D no-compilation -cpp "%OUTPUT%"
if errorlevel 1 exit /b 1
findstr /l /c:"resizeWindow" "%OUTPUT%\src\backend\WindowMode.cpp" >nul
if errorlevel 1 exit /b 1
exit /b 0

:done
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
