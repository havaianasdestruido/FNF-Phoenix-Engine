@echo off
rem Port of run-modchart-lab-typecheck.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-modchart-lab-state-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\modchart" || exit /b 1
mkdir "%TEST_SOURCE%\editors" || goto fail
xcopy /s /e /y "source\modchart\*" "%TEST_SOURCE%\modchart\" >nul || goto fail
copy /y "source\editors\ModchartLabState.hx" "%TEST_SOURCE%\editors\" >nul || goto fail
xcopy /s /e /y "tests\haxe\stubs\lab\*" "%TEST_SOURCE%\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main ModchartLabStateSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
