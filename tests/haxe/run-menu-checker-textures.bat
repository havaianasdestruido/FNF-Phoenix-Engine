@echo off
rem Port of run-menu-checker-textures.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-menu-checker-textures-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
copy /y "source\backend\MenuCheckerTextures.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main MenuCheckerTexturesSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
