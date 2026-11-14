@echo off
rem Port of run-stage-dim.sh - keep in sync with the .sh version.
rem Only the spec runs here; the options-row guards in the .sh are bash greps and
rem the .sh is what CI calls.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-stage-dim-%RANDOM%-%RANDOM%"
xcopy /e /i /y /q "tests\haxe\stubs\stage-dim" "%TEST_SOURCE%" >nul || goto fail
mkdir "%TEST_SOURCE%\play\helpers" 2>nul
copy /y "source\play\helpers\StageDimMath.hx" "%TEST_SOURCE%\play\helpers\" >nul || goto fail
copy /y "source\play\helpers\PlayStateStageDim.hx" "%TEST_SOURCE%\play\helpers\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main StageDimSpec --interp || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
