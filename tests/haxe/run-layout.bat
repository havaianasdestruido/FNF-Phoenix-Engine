@echo off
rem Port of run-layout.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-layout-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" "%TEST_SOURCE%\mobile\flixel" || exit /b 1
copy /y "source\backend\ScreenLayout.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\ModSecurity.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\backend\ScriptSecurityScanner.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\mobile\flixel\HitboxTouchLogic.hx" "%TEST_SOURCE%\mobile\flixel\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main LayoutSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ModSecuritySpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
