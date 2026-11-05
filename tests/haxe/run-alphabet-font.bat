@echo off
rem Port of run-alphabet-font.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-alphabet-font-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\objects" "%TEST_SOURCE%\backend" || exit /b 1
copy /y "source\objects\AlphabetFont.hx" "%TEST_SOURCE%\objects\" >nul || goto fail
copy /y "tests\haxe\stubs\backend\ClientPrefs.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main AlphabetFontSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
