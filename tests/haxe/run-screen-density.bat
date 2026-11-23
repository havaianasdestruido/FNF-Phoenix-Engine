@echo off
rem Port of run-screen-density.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
set "REPO=%CD%"
if not defined HAXE set "HAXE=haxe"
set "WORK=%TEMP%\phoenix-screen-density-%RANDOM%-%RANDOM%"
mkdir "%WORK%\backend" "%WORK%\flixel" || exit /b 1
copy /y "source\backend\ScreenDensity.hx" "%WORK%\backend\" >nul || goto fail
copy /y "source\backend\PlatformIcons.hx" "%WORK%\backend\" >nul || goto fail
copy /y "tests\haxe\stubs\screen-density\flixel\FlxG.hx" "%WORK%\flixel\" >nul || goto fail
%HAXE% -cp "%WORK%" -cp "%REPO%\tests\haxe" -main ScreenDensitySpec --interp || goto fail
rd /s /q "%WORK%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%WORK%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
