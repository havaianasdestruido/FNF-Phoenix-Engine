@echo off
rem Port of run-screen-filters.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
rem The patch/wiring guards in the .sh and .ps1 versions are skipped here: this
rem script has no grep. Keep the specs below in sync with them.
set "TEST_SOURCE=%TEMP%\phoenix-screen-filters-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" || exit /b 1
xcopy /e /i /q /y "tests\haxe\stubs\screen-filters" "%TEST_SOURCE%" >nul || goto fail
copy /y "source\backend\ScreenFilters.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\ChainableEffects.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ScreenFiltersSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main FlxGameFiltersSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
