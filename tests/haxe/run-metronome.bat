@echo off
rem Port of run-metronome.sh - keep in sync with the .sh / .ps1 versions.
setlocal EnableExtensions
cd /d "%~dp0..\.."
if not defined HAXE set "HAXE=haxe"
set "TEST_SOURCE=%TEMP%\phoenix-metronome-%RANDOM%-%RANDOM%"
mkdir "%TEST_SOURCE%\backend" "%TEST_SOURCE%\play\helpers" || exit /b 1
xcopy /e /i /q /y "tests\haxe\stubs\metronome" "%TEST_SOURCE%" >nul || goto fail
copy /y "source\backend\Metronome.hx" "%TEST_SOURCE%\backend\" >nul || goto fail
copy /y "source\play\helpers\PlayStateMetronome.hx" "%TEST_SOURCE%\play\helpers\" >nul || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -D FLX_PITCH -main MetronomeSpec --interp || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -D FLX_PITCH -main MetronomeSpec -cpp "%TEST_SOURCE%\cpp" --no-output || goto fail
%HAXE% -cp "%TEST_SOURCE%" -cp tests/haxe -main MetronomeSpec --swf "%TEST_SOURCE%\spec.swf" --no-output || goto fail
rd /s /q "%TEST_SOURCE%" 2>nul
exit /b 0
:fail
set "ERR=%ERRORLEVEL%"
rd /s /q "%TEST_SOURCE%" 2>nul
if "%ERR%"=="0" set "ERR=1"
exit /b %ERR%
