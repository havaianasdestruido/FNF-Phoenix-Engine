@echo off
rem Port of run-hold-to-confirm-typecheck.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-hold-confirm-flixel-%RANDOM%-%RANDOM%"
xcopy /e /i /y "tests\haxe\stubs\hold-confirm" "%TEST_SOURCE%" >nul || goto fail
mkdir "%TEST_SOURCE%\backend" 2>nul
mkdir "%TEST_SOURCE%\objects" 2>nul
copy /y "source\backend\HoldToConfirmLogic.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\objects\TouchTarget.hx" "%TEST_SOURCE%\objects\" >nul || goto fail
copy /y "source\objects\HoldToConfirm.hx" "%TEST_SOURCE%\objects\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -D FLX_TOUCH -main HoldToConfirmTypecheck --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
